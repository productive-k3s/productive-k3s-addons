#!/usr/bin/env bash

pk3s_trim_yaml_value() {
  local value="$1"
  value="${value#*:}"
  value="${value# }"
  value="${value%\"}"
  value="${value#\"}"
  printf '%s' "${value}"
}

pk3s_metadata_value() {
  local manifest="$1"
  local key="$2"
  awk -v key="${key}" '
    /^metadata:/ { in_metadata=1; next }
    in_metadata && /^[^[:space:]]/ { exit }
    in_metadata && $0 ~ "^  " key ":" { print; exit }
  ' "${manifest}"
}

pk3s_compatibility_value() {
  local manifest="$1"
  local section="$2"
  local key="$3"
  awk -v section="${section}" -v key="${key}" '
    /^spec:/ { in_spec=1; next }
    in_spec && /^  compatibility:/ { in_compatibility=1; next }
    in_compatibility && /^    requires:/ { in_requires=1; next }
    in_requires && $0 ~ "^      " section ":" { in_section=1; next }
    in_section && $0 ~ "^        " key ":" { print; exit }
    in_section && /^      [^[:space:]]/ { exit }
  ' "${manifest}"
}

pk3s_compatible_distros() {
  local manifest="$1"
  awk '
    /^spec:/ { in_spec=1; next }
    in_spec && /^  compatibility:/ { in_compatibility=1; next }
    in_compatibility && /^    requires:/ { in_requires=1; next }
    in_requires && /^      kubernetes:/ { in_kubernetes=1; next }
    in_kubernetes && /^        distros:/ { in_distros=1; next }
    in_distros && /^          - / {
      line=$0
      sub(/^          - /, "", line)
      print line
      next
    }
    in_distros { exit }
  ' "${manifest}"
}

pk3s_source_revision() {
  local path="$1"
  git -C "${path}" rev-parse HEAD 2>/dev/null || {
    printf 'could not resolve immutable source revision for %s\n' "${path}" >&2
    return 1
  }
}

pk3s_validate_source_compatibility() {
  local manifest="$1"
  local version revision contract minimum maximum distros distro
  version="$(pk3s_trim_yaml_value "$(pk3s_metadata_value "${manifest}" version)")"
  revision="$(pk3s_trim_yaml_value "$(pk3s_metadata_value "${manifest}" sourceRevision)")"
  contract="$(pk3s_trim_yaml_value "$(pk3s_compatibility_value "${manifest}" core contract)")"
  minimum="$(pk3s_trim_yaml_value "$(pk3s_compatibility_value "${manifest}" core minVersion)")"
  maximum="$(pk3s_trim_yaml_value "$(pk3s_compatibility_value "${manifest}" core maxVersionExclusive)")"
  distros="$(pk3s_compatible_distros "${manifest}" || true)"

  [[ "${version}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    printf '%s metadata.version must be a stable semantic version\n' "${manifest}" >&2
    return 1
  }
  [[ "${revision}" == "development" || "${revision}" =~ ^[0-9a-f]{40}$ ]] || {
    printf '%s metadata.sourceRevision must be development or an immutable Git SHA\n' "${manifest}" >&2
    return 1
  }
  [[ "${contract}" == "artifact/v1" ]] || {
    printf '%s requires Core contract artifact/v1\n' "${manifest}" >&2
    return 1
  }
  [[ "${minimum}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "${maximum}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    printf '%s requires stable Core compatibility bounds\n' "${manifest}" >&2
    return 1
  }
  [[ "${minimum}" != "${maximum}" && "$(printf '%s\n%s\n' "${minimum}" "${maximum}" | sort -V | head -n1)" == "${minimum}" ]] || {
    printf '%s requires a non-empty Core compatibility window\n' "${manifest}" >&2
    return 1
  }
  [[ -n "${distros}" ]] || {
    printf '%s requires at least one Kubernetes distro\n' "${manifest}" >&2
    return 1
  }
  while IFS= read -r distro; do
    [[ "${distro}" == "k3s" || "${distro}" == "rke2" ]] || {
      printf '%s declares unsupported Kubernetes distro %s\n' "${manifest}" "${distro}" >&2
      return 1
    }
  done <<<"${distros}"
}

pk3s_stage_addon_dir() {
  local addon_dir="$1"
  local stage_dir="$2"
  local source_revision="$3"
  cp -R "${addon_dir}/." "${stage_dir}/"
  awk -v revision="${source_revision}" '
    /^  sourceRevision:/ { print "  sourceRevision: " revision; found=1; next }
    /^spec:/ && !found { print "  sourceRevision: " revision; found=1 }
    { print }
  ' "${stage_dir}/addon.yaml" >"${stage_dir}/addon.yaml.tmp"
  mv "${stage_dir}/addon.yaml.tmp" "${stage_dir}/addon.yaml"
}

pk3s_stack_addons() {
  local manifest="$1"
  awk '
    /^spec:/ { in_spec=1; next }
    in_spec && /^  addons:/ { in_addons=1; next }
    in_addons && /^  [^[:space:]]/ { exit }
    !in_addons { next }
    /^    - / {
      line=$0
      sub(/^    - /, "", line)
      if (line ~ /^name:[[:space:]]*/) {
        sub(/^name:[[:space:]]*/, "", line)
        print line
      } else if (line !~ /:/) {
        print line
      }
      next
    }
    /^      name:[[:space:]]*/ {
      line=$0
      sub(/^      name:[[:space:]]*/, "", line)
      print line
    }
  ' "${manifest}"
}

pk3s_manifest_identity() {
  local manifest="$1"
  local expected_name="$2"
  local declared_name version
  declared_name="$(pk3s_trim_yaml_value "$(pk3s_metadata_value "${manifest}" name)")"
  version="$(pk3s_trim_yaml_value "$(pk3s_metadata_value "${manifest}" version)")"
  [[ "${declared_name}" == "${expected_name}" ]] || {
    printf 'source directory and metadata.name differ: %s != %s\n' "${expected_name}" "${declared_name}" >&2
    return 1
  }
  [[ -n "${version}" ]] || {
    printf 'source %s is missing metadata.version\n' "${expected_name}" >&2
    return 1
  }
  pk3s_validate_source_compatibility "${manifest}" || return $?
  printf '%s\n' "${version}"
}

pk3s_package_addon() {
  local repo_dir="$1"
  local addon_name="$2"
  local output_path="$3"
  local addon_dir="${repo_dir}/addons/${addon_name}"
  local manifest="${addon_dir}/addon.yaml" stage_dir source_revision
  [[ -f "${manifest}" ]] || {
    printf 'add-on source not found: %s\n' "${addon_name}" >&2
    return 1
  }
  pk3s_manifest_identity "${manifest}" "${addon_name}" >/dev/null
  mkdir -p "$(dirname "${output_path}")"
  stage_dir="$(mktemp -d)"
  source_revision="$(pk3s_source_revision "${repo_dir}")"
  pk3s_stage_addon_dir "${addon_dir}" "${stage_dir}" "${source_revision}"
  tar -czf "${output_path}" -C "${stage_dir}" .
  rm -rf "${stage_dir}"
}

pk3s_package_or_copy_addon() {
  local repo_dir="$1"
  local addon_name="$2"
  local addon_version="$3"
  local output_path="$4"
  local prebuilt_dir="${PK3S_PREBUILT_ADDONS_DIR:-}"
  local prebuilt_path="${prebuilt_dir}/${addon_name}-${addon_version}.tgz"

  if [[ -n "${prebuilt_dir}" && -f "${prebuilt_path}" ]]; then
    mkdir -p "$(dirname "${output_path}")"
    cp "${prebuilt_path}" "${output_path}"
    return 0
  fi
  pk3s_package_addon "${repo_dir}" "${addon_name}" "${output_path}"
}

pk3s_package_addon_dir() {
  local addon_dir="$1"
  local output_path="$2"
  local manifest="${addon_dir}/addon.yaml"
  local addon_name stage_dir source_revision

  [[ -f "${manifest}" ]] || {
    printf 'add-on source not found: %s\n' "${addon_dir}" >&2
    return 1
  }
  addon_name="$(pk3s_trim_yaml_value "$(pk3s_metadata_value "${manifest}" name)")"
  [[ -n "${addon_name}" ]] || {
    printf 'add-on source %s is missing metadata.name\n' "${addon_dir}" >&2
    return 1
  }
  pk3s_manifest_identity "${manifest}" "${addon_name}" >/dev/null
  mkdir -p "$(dirname "${output_path}")"
  stage_dir="$(mktemp -d)"
  source_revision="$(pk3s_source_revision "${addon_dir}")"
  pk3s_stage_addon_dir "${addon_dir}" "${stage_dir}" "${source_revision}"
  tar -czf "${output_path}" -C "${stage_dir}" .
  rm -rf "${stage_dir}"
}

pk3s_stack_addon_paths() {
  local manifest="$1"
  awk '
    /^spec:/ { in_spec=1; next }
    in_spec && /^  addons:/ { in_addons=1; next }
    in_addons && /^  [[:alnum:]_]/ { exit }
    !in_addons { next }
    /^[[:space:]]*- name:[[:space:]]*/ {
      name=$0
      sub(/^[[:space:]]*- name:[[:space:]]*/, "", name)
      next
    }
    /^[[:space:]]+path:[[:space:]]*/ {
      path=$0
      sub(/^[[:space:]]+path:[[:space:]]*/, "", path)
      print name "|" path
    }
  ' "${manifest}"
}

pk3s_append_resolved_addons_lock() {
  local manifest="$1"
  printf '  resolvedAddons:\n' >>"${manifest}"
  awk '
    /^  addons:/ { in_addons=1; next }
    in_addons && /^  [^[:space:]]/ { exit }
    in_addons { print }
  ' "${manifest}" >>"${manifest}.resolved"
  cat "${manifest}.resolved" >>"${manifest}"
  rm -f "${manifest}.resolved"
}

pk3s_package_adapter_stack() {
  local stack_dir="$1"
  local output_path="$2"
  local stack_manifest="${stack_dir}/stack.yaml"
  local stage_dir stack_name stack_version source_revision entry logical_name addon_path
  local addon_dir addon_manifest addon_name addon_version addon_artifact addon_digest

  [[ -f "${stack_manifest}" ]] || {
    printf 'adapter stack source not found: %s\n' "${stack_dir}" >&2
    return 1
  }
  stack_name="$(pk3s_trim_yaml_value "$(pk3s_metadata_value "${stack_manifest}" name)")"
  stack_version="$(pk3s_trim_yaml_value "$(pk3s_metadata_value "${stack_manifest}" version)")"
  [[ -n "${stack_name}" && -n "${stack_version}" ]] || {
    printf 'adapter stack source is missing metadata identity: %s\n' "${stack_dir}" >&2
    return 1
  }

  stage_dir="$(mktemp -d)"
  source_revision="$(pk3s_source_revision "${stack_dir}")"
  mkdir -p "${stage_dir}/addons" "$(dirname "${output_path}")"
  {
    printf 'apiVersion: addons.productive-k3s.io/v1\n'
    printf 'kind: Stack\n'
    printf 'metadata:\n'
    printf '  name: %s\n' "${stack_name}"
    printf '  version: %s\n' "${stack_version}"
    printf '  sourceRevision: %s\n' "${source_revision}"
    printf 'spec:\n'
    printf '  resolution:\n'
    printf '    mode: bundled\n'
    printf '  compatibility:\n'
    printf '    requires:\n'
    printf '      core:\n'
    printf '        contract: artifact/v1\n'
    printf '        minVersion: 0.9.6\n'
    printf '        maxVersionExclusive: 0.10.0\n'
    printf '      kubernetes:\n'
    printf '        distros:\n'
    printf '          - k3s\n'
    printf '  addons:\n'
    while IFS= read -r entry; do
      [[ -n "${entry}" ]] || continue
      logical_name="${entry%%|*}"
      addon_path="${entry#*|}"
      addon_dir="${stack_dir}/${addon_path}"
      addon_manifest="${addon_dir}/addon.yaml"
      [[ -f "${addon_manifest}" ]] || {
        rm -rf "${stage_dir}"
        printf 'adapter stack %s references missing add-on path: %s\n' "${stack_name}" "${addon_path}" >&2
        return 1
      }
      addon_name="$(pk3s_trim_yaml_value "$(pk3s_metadata_value "${addon_manifest}" name)")"
      addon_version="$(pk3s_manifest_identity "${addon_manifest}" "${addon_name}")"
      addon_artifact="${addon_name}-${addon_version}.tgz"
      pk3s_package_addon_dir "${addon_dir}" "${stage_dir}/addons/${addon_artifact}"
      addon_digest="$(sha256sum "${stage_dir}/addons/${addon_artifact}" | awk '{print $1}')"
      printf '    - name: %s\n' "${addon_name:-${logical_name}}"
      printf '      version: %s\n' "${addon_version}"
      printf '      source: addons/%s\n' "${addon_artifact}"
      printf '      digest: sha256:%s\n' "${addon_digest}"
    done < <(pk3s_stack_addon_paths "${stack_manifest}")
  } > "${stage_dir}/stack.yaml"
  pk3s_append_resolved_addons_lock "${stage_dir}/stack.yaml"

  for optional_path in README.md adaptation.yaml conversion-report.json values patches hooks; do
    if [[ -e "${stack_dir}/${optional_path}" ]]; then
      cp -R "${stack_dir}/${optional_path}" "${stage_dir}/${optional_path}"
    fi
  done

  tar -czf "${output_path}" -C "${stage_dir}" .
  rm -rf "${stage_dir}"
}

pk3s_package_stack() {
  local repo_dir="$1"
  local stack_name="$2"
  local output_path="$3"
  local stack_dir="${repo_dir}/stacks/${stack_name}"
  local stack_manifest="${stack_dir}/stack.yaml"
  local stage_dir source_revision core_contract core_min_version core_max_version distros distro
  local addon_name addon_dir addon_manifest addon_version addon_artifact addon_digest

  [[ -f "${stack_manifest}" ]] || {
    printf 'stack source not found: %s\n' "${stack_name}" >&2
    return 1
  }
  pk3s_manifest_identity "${stack_manifest}" "${stack_name}" >/dev/null

  stage_dir="$(mktemp -d)"
  source_revision="$(pk3s_source_revision "${repo_dir}")"
  mkdir -p "${stage_dir}/addons" "$(dirname "${output_path}")"
  core_contract="$(pk3s_trim_yaml_value "$(pk3s_compatibility_value "${stack_manifest}" core contract)")"
  core_min_version="$(pk3s_trim_yaml_value "$(pk3s_compatibility_value "${stack_manifest}" core minVersion)")"
  core_max_version="$(pk3s_trim_yaml_value "$(pk3s_compatibility_value "${stack_manifest}" core maxVersionExclusive)")"
  distros="$(pk3s_compatible_distros "${stack_manifest}" || true)"

  {
    printf 'apiVersion: addons.productive-k3s.io/v1\n'
    printf 'kind: Stack\n'
    printf 'metadata:\n'
    printf '  name: %s\n' "${stack_name}"
    printf '  version: %s\n' "$(pk3s_manifest_identity "${stack_manifest}" "${stack_name}")"
    printf '  sourceRevision: %s\n' "${source_revision}"
    printf 'spec:\n'
    printf '  resolution:\n'
    printf '    mode: bundled\n'
    printf '  compatibility:\n'
    printf '    requires:\n'
    printf '      core:\n'
    printf '        contract: %s\n' "${core_contract}"
    printf '        minVersion: %s\n' "${core_min_version}"
    printf '        maxVersionExclusive: %s\n' "${core_max_version}"
    printf '      kubernetes:\n'
    printf '        distros:\n'
    while IFS= read -r distro; do
      [[ -n "${distro}" ]] && printf '          - %s\n' "${distro}"
    done <<< "${distros}"
    printf '  addons:\n'
    while IFS= read -r addon_name; do
      [[ -n "${addon_name}" ]] || continue
      addon_dir="${repo_dir}/addons/${addon_name}"
      addon_manifest="${addon_dir}/addon.yaml"
      [[ -f "${addon_manifest}" ]] || {
        rm -rf "${stage_dir}"
        printf 'stack %s references missing add-on: %s\n' "${stack_name}" "${addon_name}" >&2
        return 1
      }
      addon_version="$(pk3s_manifest_identity "${addon_manifest}" "${addon_name}")"
      addon_artifact="${addon_name}-${addon_version}.tgz"
      pk3s_package_or_copy_addon "${repo_dir}" "${addon_name}" "${addon_version}" "${stage_dir}/addons/${addon_artifact}"
      addon_digest="$(sha256sum "${stage_dir}/addons/${addon_artifact}" | awk '{print $1}')"
      printf '    - name: %s\n' "${addon_name}"
      printf '      version: %s\n' "${addon_version}"
      printf '      source: addons/%s\n' "${addon_artifact}"
      printf '      digest: sha256:%s\n' "${addon_digest}"
    done < <(pk3s_stack_addons "${stack_manifest}")
  } > "${stage_dir}/stack.yaml"
  pk3s_append_resolved_addons_lock "${stage_dir}/stack.yaml"

  for optional_path in README.md values patches hooks; do
    if [[ -e "${stack_dir}/${optional_path}" ]]; then
      cp -R "${stack_dir}/${optional_path}" "${stage_dir}/${optional_path}"
    fi
  done

  tar -czf "${output_path}" -C "${stage_dir}" .
  rm -rf "${stage_dir}"
}

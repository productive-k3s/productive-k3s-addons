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
    in_spec && /^  runtime:/ { in_runtime=1; next }
    in_runtime && /^    compatibility:/ { in_compatibility=1; next }
    in_compatibility && $0 ~ "^      " section ":" { in_section=1; next }
    in_section && $0 ~ "^        " key ":" { print; exit }
    in_section && /^      [^[:space:]]/ { exit }
  ' "${manifest}"
}

pk3s_compatible_distros() {
  local manifest="$1"
  awk '
    /^spec:/ { in_spec=1; next }
    in_spec && /^  runtime:/ { in_runtime=1; next }
    in_runtime && /^    compatibility:/ { in_compatibility=1; next }
    in_compatibility && /^      kubernetes:/ { in_kubernetes=1; next }
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
  printf '%s\n' "${version}"
}

pk3s_package_addon() {
  local repo_dir="$1"
  local addon_name="$2"
  local output_path="$3"
  local addon_dir="${repo_dir}/addons/${addon_name}"
  local manifest="${addon_dir}/addon.yaml"
  [[ -f "${manifest}" ]] || {
    printf 'add-on source not found: %s\n' "${addon_name}" >&2
    return 1
  }
  pk3s_manifest_identity "${manifest}" "${addon_name}" >/dev/null
  mkdir -p "$(dirname "${output_path}")"
  tar -czf "${output_path}" -C "${addon_dir}" .
}

pk3s_package_stack() {
  local repo_dir="$1"
  local stack_name="$2"
  local output_path="$3"
  local stack_dir="${repo_dir}/stacks/${stack_name}"
  local stack_manifest="${stack_dir}/stack.yaml"
  local stage_dir core_min_version kubernetes_min_version distros distro
  local addon_name addon_dir addon_manifest addon_version addon_artifact

  [[ -f "${stack_manifest}" ]] || {
    printf 'stack source not found: %s\n' "${stack_name}" >&2
    return 1
  }
  pk3s_manifest_identity "${stack_manifest}" "${stack_name}" >/dev/null

  stage_dir="$(mktemp -d)"
  mkdir -p "${stage_dir}/addons" "$(dirname "${output_path}")"
  core_min_version="$(pk3s_trim_yaml_value "$(pk3s_compatibility_value "${stack_manifest}" core minVersion)")"
  kubernetes_min_version="$(pk3s_trim_yaml_value "$(pk3s_compatibility_value "${stack_manifest}" kubernetes minVersion)")"
  distros="$(pk3s_compatible_distros "${stack_manifest}" || true)"

  {
    printf 'apiVersion: addons.productive-k3s.io/v1\n'
    printf 'kind: Stack\n'
    printf 'metadata:\n'
    printf '  name: %s\n' "${stack_name}"
    printf '  version: %s\n' "$(pk3s_manifest_identity "${stack_manifest}" "${stack_name}")"
    printf 'spec:\n'
    printf '  resolution:\n'
    printf '    mode: bundled\n'
    if [[ -n "${core_min_version}" || -n "${kubernetes_min_version}" || -n "${distros}" ]]; then
      printf '  runtime:\n'
      printf '    compatibility:\n'
      if [[ -n "${core_min_version}" ]]; then
        printf '      core:\n'
        printf '        minVersion: %s\n' "${core_min_version}"
      fi
      if [[ -n "${kubernetes_min_version}" || -n "${distros}" ]]; then
        printf '      kubernetes:\n'
        if [[ -n "${kubernetes_min_version}" ]]; then
          printf '        minVersion: %s\n' "${kubernetes_min_version}"
        fi
        if [[ -n "${distros}" ]]; then
          printf '        distros:\n'
          while IFS= read -r distro; do
            [[ -n "${distro}" ]] && printf '          - %s\n' "${distro}"
          done <<< "${distros}"
        fi
      fi
    fi
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
      pk3s_package_addon "${repo_dir}" "${addon_name}" "${stage_dir}/addons/${addon_artifact}"
      printf '    - name: %s\n' "${addon_name}"
      printf '      source: addons/%s\n' "${addon_artifact}"
    done < <(pk3s_stack_addons "${stack_manifest}")
  } > "${stage_dir}/stack.yaml"

  for optional_path in README.md values patches hooks; do
    if [[ -e "${stack_dir}/${optional_path}" ]]; then
      cp -R "${stack_dir}/${optional_path}" "${stage_dir}/${optional_path}"
    fi
  done

  tar -czf "${output_path}" -C "${stage_dir}" .
  rm -rf "${stage_dir}"
}

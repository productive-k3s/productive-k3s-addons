#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/package-stack.sh --stack <name> --output <path>

Builds a self-contained stack artifact from this repository. The resulting
archive uses bundled resolution and contains one packaged artifact for every
add-on referenced by the stack.
EOF
}

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

trim_yaml_value() {
  local value="$1"
  value="${value#*:}"
  value="${value# }"
  value="${value%\"}"
  value="${value#\"}"
  printf '%s' "${value}"
}

metadata_value() {
  local manifest="$1"
  local key="$2"
  awk -v key="${key}" '
    /^metadata:/ { in_metadata=1; next }
    in_metadata && /^[^[:space:]]/ { exit }
    in_metadata && $0 ~ "^  " key ":" { print; exit }
  ' "${manifest}"
}

compatibility_value() {
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

compatible_distros() {
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

stack_addons() {
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

stack_name=""
output_path=""
while (($#)); do
  case "$1" in
    --stack)
      stack_name="${2:-}"
      shift 2
      ;;
    --output)
      output_path="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      fail "unsupported argument: $1"
      ;;
  esac
done

[[ -n "${stack_name}" ]] || fail "--stack is required"
[[ -n "${output_path}" ]] || fail "--output is required"
[[ "${stack_name}" =~ ^[a-z0-9][a-z0-9._-]*$ ]] || fail "invalid stack name: ${stack_name}"

stack_dir="${REPO_DIR}/stacks/${stack_name}"
stack_manifest="${stack_dir}/stack.yaml"
[[ -f "${stack_manifest}" ]] || fail "stack source not found: ${stack_name}"
bash "${SCRIPT_DIR}/validate-addon-package.sh" "${REPO_DIR}" --kind stack --name "${stack_name}" >/dev/null

declared_name="$(trim_yaml_value "$(metadata_value "${stack_manifest}" name)")"
stack_version="$(trim_yaml_value "$(metadata_value "${stack_manifest}" version)")"
[[ "${declared_name}" == "${stack_name}" ]] || fail "stack directory and metadata.name differ: ${stack_name} != ${declared_name}"
[[ -n "${stack_version}" ]] || fail "stack ${stack_name} is missing metadata.version"

stage_dir="$(mktemp -d)"
cleanup() {
  rm -rf "${stage_dir}"
}
trap cleanup EXIT
mkdir -p "${stage_dir}/addons" "$(dirname "${output_path}")"

core_min_version="$(trim_yaml_value "$(compatibility_value "${stack_manifest}" core minVersion)")"
kubernetes_min_version="$(trim_yaml_value "$(compatibility_value "${stack_manifest}" kubernetes minVersion)")"
distros="$(compatible_distros "${stack_manifest}" || true)"

{
  printf 'apiVersion: addons.productive-k3s.io/v1\n'
  printf 'kind: Stack\n'
  printf 'metadata:\n'
  printf '  name: %s\n' "${stack_name}"
  printf '  version: %s\n' "${stack_version}"
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
    addon_dir="${REPO_DIR}/addons/${addon_name}"
    addon_manifest="${addon_dir}/addon.yaml"
    [[ -f "${addon_manifest}" ]] || fail "stack ${stack_name} references missing add-on: ${addon_name}"
    addon_version="$(trim_yaml_value "$(metadata_value "${addon_manifest}" version)")"
    [[ -n "${addon_version}" ]] || fail "add-on ${addon_name} is missing metadata.version"
    addon_artifact="${addon_name}-${addon_version}.tgz"
    tar -czf "${stage_dir}/addons/${addon_artifact}" -C "${addon_dir}" .
    printf '    - name: %s\n' "${addon_name}"
    printf '      source: addons/%s\n' "${addon_artifact}"
  done < <(stack_addons "${stack_manifest}")
} > "${stage_dir}/stack.yaml"

for optional_path in README.md values patches hooks; do
  if [[ -e "${stack_dir}/${optional_path}" ]]; then
    cp -R "${stack_dir}/${optional_path}" "${stage_dir}/${optional_path}"
  fi
done

tar -czf "${output_path}" -C "${stage_dir}" .
printf '[INFO] Created stack artifact %s (%s %s)\n' "${output_path}" "${stack_name}" "${stack_version}"

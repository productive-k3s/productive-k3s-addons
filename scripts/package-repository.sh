#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/artifact-packaging.sh"

usage() {
  echo "Usage: $0 --output-dir <path> [--repo-dir <path>]" >&2
}

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

repo_dir="${DEFAULT_REPO_DIR}"
output_dir=""
while (($#)); do
  case "$1" in
    --repo-dir)
      repo_dir="${2:-}"
      shift 2
      ;;
    --output-dir)
      output_dir="${2:-}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      fail "unsupported argument: $1"
      ;;
  esac
done

[[ -n "${output_dir}" ]] || fail "--output-dir is required"
[[ -d "${repo_dir}" ]] || fail "repository directory not found: ${repo_dir}"
validator="${repo_dir}/scripts/validate-addon-package.sh"
[[ -f "${validator}" ]] || fail "repository validator not found: ${validator}"
bash "${validator}" "${repo_dir}" >/dev/null
mkdir -p "${output_dir}"

while IFS= read -r addon_dir; do
  [[ -f "${addon_dir}/addon.yaml" ]] || continue
  addon_name="$(basename "${addon_dir}")"
  addon_version="$(pk3s_manifest_identity "${addon_dir}/addon.yaml" "${addon_name}")"
  artifact_path="${output_dir}/${addon_name}-${addon_version}.tgz"
  pk3s_package_addon "${repo_dir}" "${addon_name}" "${artifact_path}"
  printf '[INFO] Created %s\n' "${artifact_path}"
done < <(find "${repo_dir}/addons" -mindepth 1 -maxdepth 1 -type d | sort)

while IFS= read -r stack_dir; do
  [[ -f "${stack_dir}/stack.yaml" ]] || continue
  stack_name="$(basename "${stack_dir}")"
  stack_version="$(pk3s_manifest_identity "${stack_dir}/stack.yaml" "${stack_name}")"
  artifact_path="${output_dir}/${stack_name}-${stack_version}.tgz"
  pk3s_package_stack "${repo_dir}" "${stack_name}" "${artifact_path}"
  printf '[INFO] Created %s\n' "${artifact_path}"
done < <(find "${repo_dir}/stacks" -mindepth 1 -maxdepth 1 -type d | sort)

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/lib/artifact-packaging.sh"

usage() {
  cat <<'EOF'
Usage: ./scripts/package-stack.sh --stack <name> --output <path> [--repo-dir <path>]

Builds a self-contained stack artifact with bundled add-on packages.
EOF
}

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

repo_dir="${DEFAULT_REPO_DIR}"
stack_name=""
output_path=""
while (($#)); do
  case "$1" in
    --repo-dir)
      repo_dir="${2:-}"
      shift 2
      ;;
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
[[ -d "${repo_dir}" ]] || fail "repository directory not found: ${repo_dir}"

validator="${repo_dir}/scripts/validate-addon-package.sh"
[[ -f "${validator}" ]] || fail "repository validator not found: ${validator}"
bash "${validator}" "${repo_dir}" --kind stack --name "${stack_name}" >/dev/null
pk3s_package_stack "${repo_dir}" "${stack_name}" "${output_path}"
printf '[INFO] Created stack artifact %s\n' "${output_path}"

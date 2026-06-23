#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
TEMP_CORE_DIR=""

cleanup() {
  if [[ -n "${TEMP_CORE_DIR}" && -d "${TEMP_CORE_DIR}" ]]; then
    rm -rf "${TEMP_CORE_DIR}"
  fi
}
trap cleanup EXIT

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

warn() {
  printf '[WARN] %s\n' "$*" >&2
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || fail "required command not found: $1"
}

resolve_latest_core_release() {
  need_cmd curl
  need_cmd jq
  curl -fsSL "https://api.github.com/repos/productive-k3s/productive-k3s-core/releases/latest" | jq -r '.tag_name // empty'
}

prepare_core_checkout() {
  if [[ -n "${PRODUCTIVE_K3S_CORE_REPO_DIR:-}" ]]; then
    [[ -f "${PRODUCTIVE_K3S_CORE_REPO_DIR}/productive-k3s-core.sh" && -d "${PRODUCTIVE_K3S_CORE_REPO_DIR}/scripts" ]] || fail "invalid PRODUCTIVE_K3S_CORE_REPO_DIR: ${PRODUCTIVE_K3S_CORE_REPO_DIR}"
    TEMP_CORE_DIR="$(mktemp -d)"
    cp -a "${PRODUCTIVE_K3S_CORE_REPO_DIR}/." "${TEMP_CORE_DIR}/"
    CORE_REPO_DIR="${TEMP_CORE_DIR}"
    return 0
  fi

  local ref="${CORE_VERSION:-${PRODUCTIVE_K3S_CORE_REPO_REF:-}}"
  if [[ -z "${ref}" ]]; then
    ref="$(resolve_latest_core_release)"
    [[ -n "${ref}" ]] || fail "could not resolve latest productive-k3s-core release"
  fi

  need_cmd git
  TEMP_CORE_DIR="$(mktemp -d)"
  git clone --depth 1 --branch "${ref}" \
    "${PRODUCTIVE_K3S_CORE_REPO_URL:-https://github.com/productive-k3s/productive-k3s-core.git}" \
    "${TEMP_CORE_DIR}" >/dev/null 2>&1 || fail "could not clone productive-k3s-core ref ${ref}"
  CORE_REPO_DIR="${TEMP_CORE_DIR}"
}

discover_addons() {
  find "${REPO_DIR}/addons" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
    [[ -f "${dir}/addon.yaml" ]] || continue
    basename "${dir}"
  done | sort -u
}

discover_stacks() {
  find "${REPO_DIR}/stacks" -mindepth 1 -maxdepth 1 -type d | while read -r dir; do
    [[ -f "${dir}/stack.yaml" ]] || continue
    basename "${dir}"
  done | sort -u
}

resolve_kind() {
  if [[ -n "${ADDON:-}" ]]; then
    printf 'addon\n'
    return 0
  fi
  if [[ -n "${STACK:-}" ]]; then
    printf 'stack\n'
    return 0
  fi
  fail "set ADDON=<name> or STACK=<name>"
}

resolve_name() {
  if [[ -n "${ADDON:-}" ]]; then
    printf '%s\n' "${ADDON}"
    return 0
  fi
  if [[ -n "${STACK:-}" ]]; then
    printf '%s\n' "${STACK}"
    return 0
  fi
  fail "set ADDON=<name> or STACK=<name>"
}

has_selection() {
  [[ -n "${ADDON:-}" || -n "${STACK:-}" ]]
}

run_target_level() {
  local level="$1"
  local kind="$2"
  local name="$3"
  bash "${REPO_DIR}/tests/${kind}s/run.sh" "${level}" "${name}" "${CORE_REPO_DIR}"
}

run_matrix_levels() {
  local levels=("$@")
  local level addon stack seen=0

  for level in "${levels[@]}"; do
    while IFS= read -r addon; do
      [[ -n "${addon}" ]] || continue
      seen=1
      run_target_level "${level}" addon "${addon}"
    done < <(discover_addons)
    while IFS= read -r stack; do
      [[ -n "${stack}" ]] || continue
      seen=1
      run_target_level "${level}" stack "${stack}"
    done < <(discover_stacks)
  done

  if (( seen == 0 )); then
    warn "no addon or stack sources found under ${REPO_DIR}"
  fi
}

prepare_core_checkout

case "${1:-}" in
  test-static)
    if has_selection; then
      run_target_level static "$(resolve_kind)" "$(resolve_name)"
    else
      run_matrix_levels static
    fi
    ;;
  test-contract)
    if has_selection; then
      run_target_level contract "$(resolve_kind)" "$(resolve_name)"
    else
      run_matrix_levels contract
    fi
    ;;
  test-live)
    run_target_level live "$(resolve_kind)" "$(resolve_name)"
    ;;
  test-matrix)
    run_matrix_levels static contract
    ;;
  test-live-matrix)
    run_matrix_levels live
    ;;
  *)
    fail "unsupported test command: ${1:-}"
    ;;
esac

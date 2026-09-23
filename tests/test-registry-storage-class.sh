#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REGISTRY_INSTALL_SH="${REPO_DIR}/addons/registry/scripts/install.sh"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

pass() {
  printf '[PASS] %s\n' "$1"
}

run_case() {
  local case_name="$1"
  local expected="$2"
  shift 2
  local output

  output="$(
    env "$@" bash -lc '
      set -euo pipefail
      source "${REGISTRY_INSTALL_SH}"
      kctl() {
        if [[ "$*" == "get storageclass -o jsonpath="* ]]; then
          printf "%s" "${PK3S_TEST_DEFAULT_STORAGE_CLASS:-}"
          return 0
        fi
        if [[ "$*" == "get storageclass longhorn-single" ]]; then
          [[ "${PK3S_TEST_HAS_LONGHORN_SINGLE:-n}" == "y" ]]
          return $?
        fi
        if [[ "$*" == "get storageclass longhorn" ]]; then
          [[ "${PK3S_TEST_HAS_LONGHORN:-n}" == "y" ]]
          return $?
        fi
        if [[ "$*" == "-n registry get pvc registry-data -o jsonpath={.spec.storageClassName}" ]]; then
          printf "%s" "${PK3S_TEST_EXISTING_PVC_STORAGE_CLASS:-}"
          return 0
        fi
        return 1
      }
      resolve_registry_storage_class
    '
  )"

  [[ "${output}" == "${expected}" ]] || fail "${case_name}: expected '${expected}', got '${output}'"
  pass "${case_name}"
}

export REGISTRY_INSTALL_SH

run_case "registry keeps explicit StorageClass" "custom-sc" \
  PK3S_REGISTRY_STORAGE_CLASS=custom-sc

run_case "registry reuses existing PVC StorageClass" "existing-sc" \
  PK3S_TEST_EXISTING_PVC_STORAGE_CLASS=existing-sc

run_case "registry leaves StorageClass empty when a default exists" "" \
  PK3S_TEST_DEFAULT_STORAGE_CLASS=default-sc

run_case "registry falls back to longhorn-single without a default" "longhorn-single" \
  PK3S_TEST_HAS_LONGHORN_SINGLE=y \
  PK3S_TEST_HAS_LONGHORN=y

run_case "registry falls back to longhorn without a default" "longhorn" \
  PK3S_TEST_HAS_LONGHORN=y

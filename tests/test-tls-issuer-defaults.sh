#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
EXPECTED_DEFAULT="selfsigned"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

pass() {
  printf '[PASS] %s\n' "$1"
}

assert_default() {
  local file="$1"
  local label="$2"
  if ! grep -Fq "PK3S_CLUSTER_ISSUER:-${EXPECTED_DEFAULT}" "${file}"; then
    fail "${label} must default PK3S_CLUSTER_ISSUER to ${EXPECTED_DEFAULT}"
  fi
}

assert_default "${REPO_DIR}/addons/cert-manager/scripts/install.sh" "cert-manager install"
assert_default "${REPO_DIR}/addons/rancher/scripts/install.sh" "rancher install"
assert_default "${REPO_DIR}/addons/registry/scripts/install.sh" "registry install"
assert_default "${REPO_DIR}/scripts/productive-k3s-addons-dev.sh" "live matrix wrapper"

pass "TLS issuer defaults are aligned across base stack add-ons"

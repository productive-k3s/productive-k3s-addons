#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

PK3S_ADDONS_LIVE_MATRIX_LIB_ONLY=1
# shellcheck disable=SC1091
source "${REPO_DIR}/tests/test-live-matrix-in-vm.sh"

API_STABLE_REQUIRED_SUCCESSES=3
API_STABLE_MAX_ATTEMPTS=6
API_STABLE_INTERVAL_SECONDS=0
readiness_calls=0
cluster_api_ready() {
  readiness_calls=$((readiness_calls + 1))
  case "${readiness_calls}" in
    1|3) return 1 ;;
    *) return 0 ;;
  esac
}
sleep() { :; }

wait_for_cluster_api_stable || fail "stability gate rejected a converging API"
[[ "${readiness_calls}" == "6" ]] || fail "stability gate did not restart after interrupted readiness"

API_STABLE_REQUIRED_SUCCESSES=2
API_STABLE_MAX_ATTEMPTS=3
readiness_calls=0
cluster_api_ready() {
  readiness_calls=$((readiness_calls + 1))
  return 1
}
if wait_for_cluster_api_stable; then
  fail "stability gate accepted an unavailable API"
fi
[[ "${readiness_calls}" == "3" ]] || fail "stability gate did not exhaust the configured attempts"

diagnostic_invocation=""
multipass() {
  diagnostic_invocation="$*"
}
VM_NAME="test-vm"
REMOTE_ADDONS_DIR="/home/ubuntu/productive-k3s-addons"
collect_cluster_diagnostics
[[ "${diagnostic_invocation}" == *"cluster-diagnostics/summary.log"* ]] || fail "diagnostic collection omitted the summary"
[[ "${diagnostic_invocation}" == *"cluster-diagnostics/k3s-journal.log"* ]] || fail "diagnostic collection omitted the k3s journal"

declare -F main >/dev/null || fail "live matrix harness does not expose main"
printf '[PASS] live matrix harness gates sustained API readiness and captures diagnostics\n'

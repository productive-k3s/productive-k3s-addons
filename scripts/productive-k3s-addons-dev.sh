#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/productive-k3s-addons-dev.sh <command>

Commands:
  docs-build
  docs-serve
  docs-up
  docs-down
  docs-clean
  test-clean-artifacts
  test-clean-vms
  test-clean-all
  test-checkstatus-local
  test-checkstatus-matrix
  test-checkstatus-live
  test-all
  test-static
  test-contract
  test-live
  test-matrix
  test-live-matrix
  test-live-matrix-ubuntu24
EOF
}

artifacts_dir() {
  printf '%s\n' "${TEST_ARTIFACTS_DIR:-${REPO_DIR}/test-artifacts}"
}

clean_named_suite_artifacts() {
  local suite_category="$1"
  local suite_name="$2"
  rm -f "$(artifacts_dir)"/test-"${suite_category}"-*-"${suite_name}".json
  rm -f "$(artifacts_dir)"/test-"${suite_category}"-*-"${suite_name}".log
}

run_live_matrix_with_defaults() {
  local tls_source="${PK3S_TLS_SOURCE:-secret}"
  local cluster_issuer_action="${PK3S_CLUSTER_ISSUER_ACTION:-install}"
  local cluster_issuer="${PK3S_CLUSTER_ISSUER:-selfsigned-issuer}"
  local allow_host_local_changes="${PK3S_ALLOW_HOST_LOCAL_CHANGES:-n}"
  local rancher_manage_local_hosts="${PK3S_RANCHER_MANAGE_LOCAL_HOSTS:-n}"
  local registry_manage_local_hosts="${PK3S_REGISTRY_MANAGE_LOCAL_HOSTS:-n}"
  local registry_trust_docker="${PK3S_REGISTRY_TRUST_DOCKER:-n}"

  printf '[INFO] Live matrix defaults: PK3S_TLS_SOURCE=%s PK3S_CLUSTER_ISSUER_ACTION=%s PK3S_CLUSTER_ISSUER=%s PK3S_ALLOW_HOST_LOCAL_CHANGES=%s PK3S_RANCHER_MANAGE_LOCAL_HOSTS=%s PK3S_REGISTRY_MANAGE_LOCAL_HOSTS=%s PK3S_REGISTRY_TRUST_DOCKER=%s\n' \
    "${tls_source}" "${cluster_issuer_action}" "${cluster_issuer}" "${allow_host_local_changes}" "${rancher_manage_local_hosts}" "${registry_manage_local_hosts}" "${registry_trust_docker}"

  exec env \
    PK3S_TLS_SOURCE="${tls_source}" \
    PK3S_CLUSTER_ISSUER_ACTION="${cluster_issuer_action}" \
    PK3S_CLUSTER_ISSUER="${cluster_issuer}" \
    PK3S_ALLOW_HOST_LOCAL_CHANGES="${allow_host_local_changes}" \
    PK3S_RANCHER_MANAGE_LOCAL_HOSTS="${rancher_manage_local_hosts}" \
    PK3S_REGISTRY_MANAGE_LOCAL_HOSTS="${registry_manage_local_hosts}" \
    PK3S_REGISTRY_TRUST_DOCKER="${registry_trust_docker}" \
    bash "${REPO_DIR}/tests/common.sh" test-live-matrix
}

case "${1:-help}" in
  docs-build)
    exec bash "${REPO_DIR}/docs/build.sh"
    ;;
  docs-serve|docs-up)
    exec bash "${REPO_DIR}/docs/serve.sh"
    ;;
  docs-down|docs-clean)
    exec bash "${REPO_DIR}/docs/clean.sh"
    ;;
  test-clean-artifacts)
    exec bash "${REPO_DIR}/tests/clean-test-artifacts.sh"
    ;;
  test-clean-vms)
    exec bash "${REPO_DIR}/tests/clean-test-vms.sh"
    ;;
  test-clean-all)
    exec bash "${REPO_DIR}/tests/clean-test-state.sh"
    ;;
  test-checkstatus-local)
    exec bash "${REPO_DIR}/tests/check-test-status.sh" --category local
    ;;
  test-checkstatus-matrix)
    exec bash "${REPO_DIR}/tests/check-test-status.sh" --category matrix
    ;;
  test-checkstatus-live)
    exec bash "${REPO_DIR}/tests/check-test-status.sh" --category live
    ;;
  test-all)
    clean_named_suite_artifacts local test-all
    exec bash "${REPO_DIR}/tests/run-suite-with-artifact.sh" local test-all make -C "${REPO_DIR}/tests" test-all-raw
    ;;
  test-all-raw)
    exec bash "${REPO_DIR}/tests/common.sh" test-static && \
      bash "${REPO_DIR}/scripts/validate-addon-package.sh" "${REPO_DIR}" && \
      bash "${REPO_DIR}/tests/common.sh" test-contract
    ;;
  test-static|test-contract|test-live|test-matrix|test-live-matrix|test-live-matrix-ubuntu24)
    case "$1" in
      test-matrix)
        clean_named_suite_artifacts matrix test-matrix
        exec bash "${REPO_DIR}/tests/run-suite-with-artifact.sh" matrix test-matrix bash "${REPO_DIR}/tests/common.sh" test-matrix
        ;;
      test-live-matrix)
        clean_named_suite_artifacts live test-live-matrix
        exec bash "${REPO_DIR}/tests/run-suite-with-artifact.sh" live test-live-matrix bash "${REPO_DIR}/scripts/productive-k3s-addons-dev.sh" test-live-matrix-raw
        ;;
      test-live-matrix-ubuntu24)
        clean_named_suite_artifacts live test-live-matrix-ubuntu24
        exec bash "${REPO_DIR}/tests/run-suite-with-artifact.sh" live test-live-matrix-ubuntu24 bash "${REPO_DIR}/tests/test-live-matrix-in-vm.sh"
        ;;
      *)
        exec bash "${REPO_DIR}/tests/common.sh" "$@"
        ;;
    esac
    ;;
  test-live-matrix-raw)
    run_live_matrix_with_defaults
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    printf 'Unsupported development command: %s\n\n' "${1:-}" >&2
    usage >&2
    exit 2
    ;;
esac

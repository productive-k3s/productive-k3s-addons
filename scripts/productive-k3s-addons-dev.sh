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
  test-checkstatus-local
  test-checkstatus-matrix
  test-checkstatus-live
  test-all
  test-static
  test-contract
  test-live
  test-matrix
  test-live-matrix
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
  test-static|test-contract|test-live|test-matrix|test-live-matrix)
    case "$1" in
      test-matrix)
        clean_named_suite_artifacts matrix test-matrix
        exec bash "${REPO_DIR}/tests/run-suite-with-artifact.sh" matrix test-matrix bash "${REPO_DIR}/tests/common.sh" test-matrix
        ;;
      test-live-matrix)
        clean_named_suite_artifacts live test-live-matrix
        exec bash "${REPO_DIR}/tests/run-suite-with-artifact.sh" live test-live-matrix bash "${REPO_DIR}/tests/common.sh" test-live-matrix
        ;;
      *)
        exec bash "${REPO_DIR}/tests/common.sh" "$@"
        ;;
    esac
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

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
  test-static
  test-contract
  test-live
  test-matrix
  test-live-matrix
EOF
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
  test-static|test-contract|test-live|test-matrix|test-live-matrix)
    exec bash "${REPO_DIR}/tests/common.sh" "$@"
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

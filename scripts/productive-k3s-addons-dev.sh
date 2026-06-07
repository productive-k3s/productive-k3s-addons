#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<'EOF'
Usage: ./scripts/productive-k3s-addons-dev.sh <command>

Commands:
  test-static
  test-contract
  test-live
  test-matrix
  test-live-matrix
EOF
}

case "${1:-help}" in
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

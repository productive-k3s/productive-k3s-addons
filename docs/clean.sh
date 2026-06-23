#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rm -rf "${ROOT_DIR}/.venv" "${ROOT_DIR}/site"
rm -f "${ROOT_DIR}/.mkdocs.pid" "${ROOT_DIR}/.mkdocs.log"

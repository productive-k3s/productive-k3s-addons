#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${ROOT_DIR}/build.sh" >/dev/null
source "${ROOT_DIR}/.venv/bin/activate"
mkdocs serve --config-file "${ROOT_DIR}/mkdocs.yml" --dev-addr 127.0.0.1:8000

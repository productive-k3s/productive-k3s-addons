#!/usr/bin/env bash
set -euo pipefail
pk3s_addon_backup() {
  echo "No generic backup strategy was generated. Configure backup explicitly for stateful components." >&2
}
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then pk3s_addon_backup "$@"; fi

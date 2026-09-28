#!/usr/bin/env bash
set -euo pipefail
HELM_BIN="${PK3S_HELM_BIN:-helm}"
RELEASE_NAME="${PK3S_ADDON_RELEASE_NAME:-openship-whoami-redis-web}"
NAMESPACE="${PK3S_ADDON_NAMESPACE:-pk3s-openship-whoami-redis}"
pk3s_addon_validate() { "${HELM_BIN}" status "${RELEASE_NAME}" -n "${NAMESPACE}" >/dev/null; }
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then pk3s_addon_validate "$@"; fi

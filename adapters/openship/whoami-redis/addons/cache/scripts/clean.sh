#!/usr/bin/env bash
set -euo pipefail
HELM_BIN="${PK3S_HELM_BIN:-helm}"
RELEASE_NAME="${PK3S_ADDON_RELEASE_NAME:-openship-whoami-redis-cache}"
NAMESPACE="${PK3S_ADDON_NAMESPACE:-pk3s-openship-whoami-redis}"
pk3s_addon_clean() { "${HELM_BIN}" uninstall "${RELEASE_NAME}" -n "${NAMESPACE}" || true; }
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then pk3s_addon_clean "$@"; fi

#!/usr/bin/env bash

ADDON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ADDON_SCRIPT_DIR}/../../../scripts/addon-host-runtime.sh"

pk3s_addon_clean() {
  if declare -F pk3s_runtime_server_active >/dev/null 2>&1 && ! pk3s_runtime_server_active; then
    return 0
  fi

  pk3s_addon_kubectl delete clusterrolebinding pk3s-popeye-readonly --ignore-not-found >/dev/null 2>&1 || true
  pk3s_addon_kubectl delete clusterrole pk3s-popeye-readonly --ignore-not-found >/dev/null 2>&1 || true
  pk3s_addon_kubectl delete namespace pk3s-popeye --ignore-not-found --wait=false >/dev/null 2>&1 || true
}

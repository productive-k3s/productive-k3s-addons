#!/usr/bin/env bash

pk3s_addon_clean() {
  local namespace="${PK3S_GEOSERVER_NAMESPACE:-geoserver}"
  local release_name="${PK3S_GEOSERVER_RELEASE_NAME:-geoserver-cloud}"
  if declare -F pk3s_runtime_server_active >/dev/null 2>&1 && ! pk3s_runtime_server_active; then
    return 0
  fi
  helm uninstall "${release_name}" -n "${namespace}" >/dev/null 2>&1 || true
  kubectl_k3s delete namespace "${namespace}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}

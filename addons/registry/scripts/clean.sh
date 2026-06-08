#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../scripts/addon-host-runtime.sh"

pk3s_addon_clean() {
  if ! service_active k3s; then
    return 0
  fi

  log "Deleting registry addon resources"
  kubectl_k3s delete ingress registry -n registry --ignore-not-found --wait=false || true
  kubectl_k3s delete service registry -n registry --ignore-not-found --wait=false || true
  kubectl_k3s delete deployment registry -n registry --ignore-not-found --wait=false || true
  kubectl_k3s delete pvc registry-data -n registry --ignore-not-found --wait=false || true
  kubectl_k3s delete certificate registry-tls -n registry --ignore-not-found --wait=false || true
  kubectl_k3s delete secret registry-auth -n registry --ignore-not-found || true
  kubectl_k3s delete namespace registry --ignore-not-found --wait=false >/dev/null 2>&1 || true

  local registry_host="${PK3S_REGISTRY_HOST:-}"
  if [[ -z "${registry_host}" ]]; then
    registry_host="$(kubectl_k3s get ingress registry -n registry -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || true)"
  fi
  if [[ -n "${registry_host}" ]]; then
    pk3s_remove_local_hosts_entry "${registry_host}"
    pk3s_remove_local_docker_trust "${registry_host}"
  fi
}

pk3s_registry_clean() {
  pk3s_addon_clean "$@"
}

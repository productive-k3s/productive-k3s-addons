#!/usr/bin/env bash

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
}

pk3s_registry_clean() {
  pk3s_addon_clean "$@"
}

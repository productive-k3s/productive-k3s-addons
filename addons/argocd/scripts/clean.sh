#!/usr/bin/env bash

pk3s_addon_clean() {
  local namespace="${PK3S_ARGOCD_NAMESPACE:-argocd}"
  if declare -F pk3s_runtime_server_active >/dev/null 2>&1 && ! pk3s_runtime_server_active; then
    return 0
  fi
  "${PK3S_HELM_BIN:-helm}" uninstall argocd -n "${namespace}" >/dev/null 2>&1 || true
  kubectl_k3s delete namespace "${namespace}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}

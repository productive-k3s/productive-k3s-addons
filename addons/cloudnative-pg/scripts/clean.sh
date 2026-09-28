#!/usr/bin/env bash

pk3s_addon_clean() {
  local operator_namespace="${PK3S_CNPG_OPERATOR_NAMESPACE:-cnpg-system}"
  local database_namespace="${PK3S_CNPG_DATABASE_NAMESPACE:-database}"
  local cluster_name="${PK3S_CNPG_CLUSTER_NAME:-pk3s-postgres}"
  if declare -F pk3s_runtime_server_active >/dev/null 2>&1 && ! pk3s_runtime_server_active; then
    return 0
  fi
  kubectl_k3s delete cluster "${cluster_name}" -n "${database_namespace}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  "${PK3S_HELM_BIN:-helm}" uninstall cloudnative-pg -n "${operator_namespace}" >/dev/null 2>&1 || true
  kubectl_k3s delete namespace "${operator_namespace}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
}

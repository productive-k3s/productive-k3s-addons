#!/usr/bin/env bash

pk3s_addon_validate() {
  local operator_namespace="${PK3S_CNPG_OPERATOR_NAMESPACE:-cnpg-system}"
  local database_namespace="${PK3S_CNPG_DATABASE_NAMESPACE:-database}"
  local cluster_name="${PK3S_CNPG_CLUSTER_NAME:-pk3s-postgres}"
  info "Checking CloudNativePG"
  if ! k get namespace "${operator_namespace}" >/dev/null 2>&1; then
    info "CloudNativePG is not installed; skipping CloudNativePG-specific checks"
    return
  fi

  check_namespace_rollup "${operator_namespace}" "CloudNativePG operator"
  if k get crd clusters.postgresql.cnpg.io >/dev/null 2>&1; then
    record_ok "CloudNativePG Cluster CRD exists"
  else
    record_warn "CloudNativePG Cluster CRD is missing"
  fi
  if k get cluster "${cluster_name}" -n "${database_namespace}" >/dev/null 2>&1; then
    record_ok "CloudNativePG cluster ${database_namespace}/${cluster_name} exists"
    safe_run k get cluster "${cluster_name}" -n "${database_namespace}" 2>/dev/null || true
  else
    info "CloudNativePG operator is installed but default database cluster is absent"
  fi
}

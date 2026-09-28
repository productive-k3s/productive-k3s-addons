#!/usr/bin/env bash

pk3s_addon_backup() {
  local output_dir="$1"
  local operator_namespace="${PK3S_CNPG_OPERATOR_NAMESPACE:-cnpg-system}"
  local database_namespace="${PK3S_CNPG_DATABASE_NAMESPACE:-database}"
  if k get namespace "${operator_namespace}" >/dev/null 2>&1; then
    safe_write_cmd "$output_dir/namespaces/${operator_namespace}-all.yaml" k get all -n "${operator_namespace}" -o yaml
  fi
  if k get namespace "${database_namespace}" >/dev/null 2>&1; then
    safe_write_cmd "$output_dir/namespaces/${database_namespace}-cnpg-clusters.yaml" k get clusters.postgresql.cnpg.io -n "${database_namespace}" -o yaml
    safe_write_cmd "$output_dir/namespaces/${database_namespace}-cnpg-secrets.yaml" k get secret -n "${database_namespace}" -o yaml
  fi
}

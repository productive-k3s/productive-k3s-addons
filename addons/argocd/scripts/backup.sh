#!/usr/bin/env bash

pk3s_addon_backup() {
  local output_dir="$1"
  local namespace="${PK3S_ARGOCD_NAMESPACE:-argocd}"
  if k get namespace "${namespace}" >/dev/null 2>&1; then
    log "Exporting namespace ${namespace}"
    safe_write_cmd "$output_dir/namespaces/${namespace}-all.yaml" k get all -n "${namespace}" -o yaml
    safe_write_cmd "$output_dir/namespaces/${namespace}-configmaps.yaml" k get configmap -n "${namespace}" -o yaml
    safe_write_cmd "$output_dir/namespaces/${namespace}-secrets.yaml" k get secret -n "${namespace}" -o yaml
  fi
  safe_write_cmd "$output_dir/cluster/argocd-applications.yaml" k get applications.argoproj.io -A -o yaml
}

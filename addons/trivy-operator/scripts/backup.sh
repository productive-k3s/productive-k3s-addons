#!/usr/bin/env bash

pk3s_addon_backup() {
  local output_dir="$1"
  local namespace="${PK3S_TRIVY_OPERATOR_NAMESPACE:-trivy-system}"
  if k get namespace "${namespace}" >/dev/null 2>&1; then
    log "Exporting namespace ${namespace}"
    safe_write_cmd "$output_dir/namespaces/${namespace}-all.yaml" k get all -n "${namespace}" -o yaml
    safe_write_cmd "$output_dir/namespaces/${namespace}-pods.txt" k get pods -n "${namespace}" -o wide
  fi
  safe_write_cmd "$output_dir/cluster/trivy-operator-reports.yaml" k get vulnerabilityreports,configauditreports -A -o yaml
}

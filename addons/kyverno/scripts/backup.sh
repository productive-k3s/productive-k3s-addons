#!/usr/bin/env bash

pk3s_addon_backup() {
  local output_dir="$1"
  local namespace="${PK3S_KYVERNO_NAMESPACE:-kyverno}"
  if k get namespace "${namespace}" >/dev/null 2>&1; then
    log "Exporting namespace ${namespace}"
    safe_write_cmd "$output_dir/namespaces/${namespace}-all.yaml" k get all -n "${namespace}" -o yaml
  fi
  safe_write_cmd "$output_dir/cluster/kyverno-policies.yaml" k get clusterpolicy -l app.kubernetes.io/part-of=productive-k3s -o yaml
  safe_write_cmd "$output_dir/cluster/kyverno-policyreports.yaml" k get policyreports -A -o yaml
}

#!/usr/bin/env bash

pk3s_addon_backup() {
  local output_dir="$1"

  if k get namespace pk3s-popeye >/dev/null 2>&1; then
    log "Exporting namespace pk3s-popeye"
    safe_write_cmd "$output_dir/namespaces/pk3s-popeye-all.yaml" k get all -n pk3s-popeye -o yaml
    safe_write_cmd "$output_dir/namespaces/pk3s-popeye-pods.txt" k get pods -n pk3s-popeye -o wide
    safe_write_cmd "$output_dir/namespaces/pk3s-popeye-logs.txt" k logs -n pk3s-popeye job/pk3s-popeye-scan --tail=-1
  fi

  safe_write_cmd "$output_dir/cluster/pk3s-popeye-rbac.yaml" k get clusterrole,clusterrolebinding -l app.kubernetes.io/name=popeye -o yaml
}

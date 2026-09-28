#!/usr/bin/env bash

pk3s_addon_backup() {
  local output_dir="$1"

  if k get namespace pk3s-kubent >/dev/null 2>&1; then
    log "Exporting namespace pk3s-kubent"
    safe_write_cmd "$output_dir/namespaces/pk3s-kubent-all.yaml" k get all -n pk3s-kubent -o yaml
    safe_write_cmd "$output_dir/namespaces/pk3s-kubent-pods.txt" k get pods -n pk3s-kubent -o wide
    safe_write_cmd "$output_dir/namespaces/pk3s-kubent-logs.txt" k logs -n pk3s-kubent job/pk3s-kubent-scan --tail=-1
  fi

  safe_write_cmd "$output_dir/cluster/pk3s-kubent-rbac.yaml" k get clusterrole,clusterrolebinding -l app.kubernetes.io/name=kubent -o yaml
}

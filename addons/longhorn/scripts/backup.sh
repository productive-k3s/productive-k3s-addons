#!/usr/bin/env bash

pk3s_addon_backup() {
  local output_dir="$1"

  if k get namespace longhorn-system >/dev/null 2>&1; then
    log "Exporting namespace longhorn-system"
    safe_write_cmd "$output_dir/namespaces/longhorn-system-all.yaml" k get all -n longhorn-system -o yaml
    safe_write_cmd "$output_dir/namespaces/longhorn-system-pods.txt" k get pods -n longhorn-system -o wide
    safe_write_cmd "$output_dir/namespaces/longhorn-system-secrets.yaml" k get secret -n longhorn-system -o yaml
    safe_write_cmd "$output_dir/namespaces/longhorn-system-configmaps.yaml" k get configmap -n longhorn-system -o yaml
    safe_write_cmd "$output_dir/namespaces/longhorn-system-pvc.yaml" k get pvc -n longhorn-system -o yaml
  fi

  safe_write_cmd "$output_dir/cluster/longhorn-storageclasses.yaml" k get sc -o yaml
  safe_write_cmd "$output_dir/cluster/longhorn-volumes.yaml" k get volumes.longhorn.io -n longhorn-system -o yaml
}

pk3s_longhorn_backup() {
  pk3s_addon_backup "$@"
}

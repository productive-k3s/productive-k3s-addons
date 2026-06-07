#!/usr/bin/env bash

pk3s_addon_backup() {
  local output_dir="$1"

  if k get namespace cattle-system >/dev/null 2>&1; then
    log "Exporting namespace cattle-system"
    safe_write_cmd "$output_dir/namespaces/cattle-system-all.yaml" k get all -n cattle-system -o yaml
    safe_write_cmd "$output_dir/namespaces/cattle-system-pods.txt" k get pods -n cattle-system -o wide
    safe_write_cmd "$output_dir/namespaces/cattle-system-ingress.yaml" k get ingress -n cattle-system -o yaml
    safe_write_cmd "$output_dir/namespaces/cattle-system-secrets.yaml" k get secret -n cattle-system -o yaml
    safe_write_cmd "$output_dir/namespaces/cattle-system-configmaps.yaml" k get configmap -n cattle-system -o yaml
  fi
}

pk3s_rancher_backup() {
  pk3s_addon_backup "$@"
}

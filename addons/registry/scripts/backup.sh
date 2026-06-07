#!/usr/bin/env bash

pk3s_addon_backup() {
  local output_dir="$1"
  if ! k get namespace registry >/dev/null 2>&1; then
    return 0
  fi

  log "Exporting namespace registry"
  safe_write_cmd "$output_dir/namespaces/registry-all.yaml" k get all -n registry -o yaml
  safe_write_cmd "$output_dir/namespaces/registry-pods.txt" k get pods -n registry -o wide
  safe_write_cmd "$output_dir/namespaces/registry-ingress.yaml" k get ingress -n registry -o yaml
  safe_write_cmd "$output_dir/namespaces/registry-secrets.yaml" k get secret -n registry -o yaml
  safe_write_cmd "$output_dir/namespaces/registry-configmaps.yaml" k get configmap -n registry -o yaml
  safe_write_cmd "$output_dir/namespaces/registry-pvc.yaml" k get pvc -n registry -o yaml
}

pk3s_registry_backup() {
  pk3s_addon_backup "$@"
}

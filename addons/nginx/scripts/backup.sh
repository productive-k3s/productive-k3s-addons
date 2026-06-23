#!/usr/bin/env bash

pk3s_addon_backup() {
  local output_dir="$1"
  if ! k get namespace pk3s-nginx >/dev/null 2>&1; then
    return 0
  fi

  log "Exporting namespace pk3s-nginx"
  safe_write_cmd "$output_dir/namespaces/pk3s-nginx-all.yaml" k get all -n pk3s-nginx -o yaml
  safe_write_cmd "$output_dir/namespaces/pk3s-nginx-pods.txt" k get pods -n pk3s-nginx -o wide
  safe_write_cmd "$output_dir/namespaces/pk3s-nginx-ingress.yaml" k get ingress -n pk3s-nginx -o yaml
  safe_write_cmd "$output_dir/namespaces/pk3s-nginx-secrets.yaml" k get secret -n pk3s-nginx -o yaml
}

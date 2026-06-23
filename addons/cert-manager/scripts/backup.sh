#!/usr/bin/env bash

pk3s_addon_backup() {
  local output_dir="$1"

  if k get namespace cert-manager >/dev/null 2>&1; then
    log "Exporting namespace cert-manager"
    safe_write_cmd "$output_dir/namespaces/cert-manager-all.yaml" k get all -n cert-manager -o yaml
    safe_write_cmd "$output_dir/namespaces/cert-manager-pods.txt" k get pods -n cert-manager -o wide
    safe_write_cmd "$output_dir/namespaces/cert-manager-secrets.yaml" k get secret -n cert-manager -o yaml
    safe_write_cmd "$output_dir/namespaces/cert-manager-configmaps.yaml" k get configmap -n cert-manager -o yaml
  fi

  safe_write_cmd "$output_dir/cluster/cert-manager-clusterissuers.yaml" k get clusterissuers -o yaml
  safe_write_cmd "$output_dir/cluster/cert-manager-certificates.yaml" k get certificates -A -o yaml
}

pk3s_cert_manager_backup() {
  pk3s_addon_backup "$@"
}

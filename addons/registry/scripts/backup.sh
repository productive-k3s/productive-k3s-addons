#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../scripts/addon-host-runtime.sh"

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

  local registry_host="${PK3S_REGISTRY_HOST:-}"
  if [[ -z "${registry_host}" ]]; then
    registry_host="$(k get ingress registry -n registry -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || true)"
  fi
  if [[ -n "${registry_host}" ]]; then
    grep -E "[[:space:]]${registry_host}$" /etc/hosts > "${output_dir}/host-registry-hosts.txt" 2>/dev/null || true
    if [[ -d "/etc/docker/certs.d/${registry_host}" ]]; then
      mkdir -p "${output_dir}/docker"
      sudo cp -a "/etc/docker/certs.d/${registry_host}" "${output_dir}/docker/${registry_host}"
      sudo chown -R "$(id -u):$(id -g)" "${output_dir}/docker/${registry_host}"
    fi
  fi
}

pk3s_registry_backup() {
  pk3s_addon_backup "$@"
}

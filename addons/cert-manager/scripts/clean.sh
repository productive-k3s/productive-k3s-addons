#!/usr/bin/env bash

pk3s_addon_clean() {
  if ! pk3s_runtime_server_active; then
    return 0
  fi

  kubectl_k3s delete certificates --all -A --ignore-not-found >/dev/null 2>&1 || true
  local issuer
  for issuer in selfsigned letsencrypt-staging letsencrypt-production; do
    kubectl_k3s delete clusterissuer "$issuer" --ignore-not-found || true
  done
  kubectl_k3s delete namespace cert-manager --ignore-not-found --wait=false >/dev/null 2>&1 || true
}

pk3s_cert_manager_clean() {
  pk3s_addon_clean "$@"
}

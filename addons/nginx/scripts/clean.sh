#!/usr/bin/env bash

pk3s_addon_clean() {
  if ! pk3s_runtime_server_active; then
    return 0
  fi

  kubectl_k3s delete namespace pk3s-nginx --ignore-not-found --wait=false >/dev/null 2>&1 || true
}

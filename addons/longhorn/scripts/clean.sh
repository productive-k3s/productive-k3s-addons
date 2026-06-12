#!/usr/bin/env bash

pk3s_addon_clean() {
  if ! pk3s_runtime_server_active; then
    return 0
  fi

  kubectl_k3s delete namespace longhorn-system --ignore-not-found --wait=false >/dev/null 2>&1 || true
  delete_named_resources_matching validatingwebhookconfigurations 'longhorn'
  delete_named_resources_matching mutatingwebhookconfigurations 'longhorn'
  kubectl_k3s delete storageclass longhorn longhorn-static longhorn-single --ignore-not-found || true
  kubectl_k3s delete csidriver driver.longhorn.io --ignore-not-found || true
  delete_named_resources_matching crd 'longhorn\.io'
}

pk3s_longhorn_clean() {
  pk3s_addon_clean "$@"
}

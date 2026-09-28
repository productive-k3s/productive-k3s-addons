#!/usr/bin/env bash

pk3s_addon_clean() {
  local helm_bin="${PK3S_HELM_BIN:-helm}"
  local helm_timeout="${PK3S_LONGHORN_CLEAN_TIMEOUT:-10m}"

  if ! pk3s_runtime_server_active; then
    return 0
  fi

  if kubectl_k3s get namespace longhorn-system >/dev/null 2>&1; then
    if kubectl_k3s -n longhorn-system get settings.longhorn.io deleting-confirmation-flag >/dev/null 2>&1; then
      kubectl_k3s -n longhorn-system patch settings.longhorn.io deleting-confirmation-flag \
        --type=merge -p '{"value":"true"}' >/dev/null
    fi

    if "${helm_bin}" status longhorn --namespace longhorn-system >/dev/null 2>&1; then
      "${helm_bin}" uninstall longhorn \
        --namespace longhorn-system \
        --wait \
        --timeout "${helm_timeout}"
    fi

    kubectl_k3s delete namespace longhorn-system --ignore-not-found --wait=false >/dev/null
  fi

  delete_named_resources_matching validatingwebhookconfigurations 'longhorn'
  delete_named_resources_matching mutatingwebhookconfigurations 'longhorn'
  kubectl_k3s delete storageclass longhorn longhorn-static longhorn-single --ignore-not-found || true
  kubectl_k3s delete csidriver driver.longhorn.io --ignore-not-found || true
  delete_named_resources_matching crd 'longhorn\.io'
}

pk3s_longhorn_clean() {
  pk3s_addon_clean "$@"
}

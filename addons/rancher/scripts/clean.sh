#!/usr/bin/env bash

ADDON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ADDON_SCRIPT_DIR}/../../../scripts/addon-host-runtime.sh"

pk3s_addon_clean() {
  if ! service_active k3s; then
    return 0
  fi

  local ns
  for ns in cattle-turtles-system cattle-capi-system cattle-fleet-local-system cattle-fleet-system cattle-system; do
    kubectl_k3s delete namespace "$ns" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  done
  delete_named_resources_matching validatingwebhookconfigurations 'rancher|fleet|cattle'
  delete_named_resources_matching mutatingwebhookconfigurations 'rancher|fleet|cattle'
  delete_named_resources_matching apiservices 'cattle|fleet'
  delete_named_resources_matching crd 'cattle\.io|fleet\.cattle\.io'

  local rancher_host="${PK3S_RANCHER_HOST:-}"
  if [[ -z "${rancher_host}" ]]; then
    rancher_host="$(kubectl_k3s get ingress rancher -n cattle-system -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || true)"
  fi
  [[ -n "${rancher_host}" ]] && pk3s_remove_local_hosts_entry "${rancher_host}"
}

pk3s_rancher_clean() {
  pk3s_addon_clean "$@"
}

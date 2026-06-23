#!/usr/bin/env bash

ADDON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ADDON_SCRIPT_DIR}/../../../scripts/addon-host-runtime.sh"

pk3s_addon_clean() {
  local rancher_host="${1:-${PK3S_RANCHER_HOST:-}}"

  if ! pk3s_runtime_server_active; then
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

  if [[ -z "${rancher_host}" ]]; then
    rancher_host="$(kubectl_k3s get ingress rancher -n cattle-system -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || true)"
  fi
  if [[ -n "${rancher_host}" ]]; then
    pk3s_remove_local_hosts_entry "${rancher_host}"
  fi
  return 0
}

pk3s_rancher_clean() {
  pk3s_addon_clean "$@"
}

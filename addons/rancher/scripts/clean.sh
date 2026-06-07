#!/usr/bin/env bash

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
}

pk3s_rancher_clean() {
  pk3s_addon_clean "$@"
}

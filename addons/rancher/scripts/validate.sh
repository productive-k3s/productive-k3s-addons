#!/usr/bin/env bash

pk3s_addon_validate() {
  info "Checking Rancher"
  if ! k get namespace cattle-system >/dev/null 2>&1; then
    info "Rancher is not installed; skipping Rancher-specific checks"
    return
  fi

  check_namespace_rollup "cattle-system" "Rancher"

  if k get secret tls-ca -n cattle-system >/dev/null 2>&1; then
    record_ok "Rancher private CA secret exists"
  else
    record_warn "Rancher private CA secret 'tls-ca' is missing"
  fi

  if k get ingress rancher -n cattle-system >/dev/null 2>&1; then
    record_ok "Rancher ingress exists"
  else
    record_warn "Rancher ingress does not exist"
  fi
}

pk3s_rancher_validate() {
  pk3s_addon_validate "$@"
}

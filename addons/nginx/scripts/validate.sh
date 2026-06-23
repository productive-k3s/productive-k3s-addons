#!/usr/bin/env bash

pk3s_addon_validate() {
  info "Checking nginx"
  if ! k get namespace pk3s-nginx >/dev/null 2>&1; then
    info "nginx is not installed; skipping nginx-specific checks"
    return 0
  fi

  check_namespace_rollup "pk3s-nginx" "nginx"

  if k get svc pk3s-nginx -n pk3s-nginx >/dev/null 2>&1; then
    record_ok "nginx service exists"
  else
    record_warn "nginx service is missing"
  fi
}

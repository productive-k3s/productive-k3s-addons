#!/usr/bin/env bash

pk3s_addon_validate() {
  info "Checking cert-manager"
  if ! k get namespace cert-manager >/dev/null 2>&1; then
    if k get namespace cattle-system >/dev/null 2>&1 || k get namespace registry >/dev/null 2>&1; then
      record_warn "cert-manager namespace does not exist even though TLS-dependent components are present"
    else
      info "cert-manager is not installed; skipping cert-manager-specific checks"
    fi
    return
  fi

  check_namespace_rollup "cert-manager" "cert-manager"

  local issuers
  if ! issuers="$(safe_run k get clusterissuer 2>/dev/null)"; then
    record_warn "unable to query ClusterIssuers"
    return
  fi

  if printf '%s\n' "$issuers" | awk 'NR>1 {print}' | grep -q .; then
    record_ok "ClusterIssuer resources are present"
  else
    record_warn "no ClusterIssuer resources found"
  fi

  local certs not_ready
  if certs="$(safe_run k get certificates -A 2>/dev/null)"; then
    not_ready="$(printf '%s\n' "$certs" | awk 'NR>1 && $3 != "True" {print}')"
    if [[ -n "$not_ready" ]]; then
      record_warn "some certificates are not Ready"
      printf '%s\n' "$not_ready"
    else
      record_ok "all certificates are Ready"
    fi
  fi
}

pk3s_cert_manager_validate() {
  pk3s_addon_validate "$@"
}

#!/usr/bin/env bash

ADDON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ADDON_SCRIPT_DIR}/../../../scripts/addon-host-runtime.sh"

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

  local rancher_host
  rancher_host="$(k get ingress rancher -n cattle-system -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || true)"
  if [[ -n "${rancher_host}" ]]; then
    if getent hosts "${rancher_host}" >/dev/null 2>&1; then
      record_ok "${rancher_host} resolves locally"
      local rancher_code
      rancher_code="$(curl -k -s -o /dev/null -w '%{http_code}' --max-time 10 "https://${rancher_host}" || true)"
      if [[ "${rancher_code}" =~ ^(200|302|401|403)$ ]]; then
        record_ok "Rancher HTTPS endpoint responds with HTTP ${rancher_code}"
      else
        record_warn "Rancher HTTPS endpoint did not return an expected code (got '${rancher_code:-none}')"
      fi
    elif [[ "${APPLY_SETTING_RANCHER_MANAGE_LOCAL_HOSTS:-}" == "y" ]]; then
      record_warn "${rancher_host} does not resolve locally"
    else
      info "${rancher_host} was not configured for local host resolution; skipping local HTTPS probe"
    fi
  fi
}

pk3s_rancher_validate() {
  pk3s_addon_validate "$@"
}

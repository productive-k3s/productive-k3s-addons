#!/usr/bin/env bash

pk3s_addon_validate() {
  local namespace="${PK3S_ARGOCD_NAMESPACE:-argocd}"
  info "Checking Argo CD"
  if ! k get namespace "${namespace}" >/dev/null 2>&1; then
    info "Argo CD is not installed; skipping Argo CD-specific checks"
    return
  fi

  check_namespace_rollup "${namespace}" "Argo CD"
  if k get deployment argocd-server -n "${namespace}" >/dev/null 2>&1; then
    record_ok "Argo CD server deployment exists"
  else
    record_warn "Argo CD server deployment is missing"
  fi
  safe_run k get applications.argoproj.io -A 2>/dev/null || true
}

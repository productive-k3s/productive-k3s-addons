#!/usr/bin/env bash

pk3s_addon_validate() {
  local namespace="${PK3S_KYVERNO_NAMESPACE:-kyverno}"
  info "Checking Kyverno"
  if ! k get namespace "${namespace}" >/dev/null 2>&1; then
    info "Kyverno is not installed; skipping Kyverno-specific checks"
    return
  fi

  check_namespace_rollup "${namespace}" "Kyverno"
  if k get clusterpolicy pk3s-audit-disallow-latest-image-tag >/dev/null 2>&1 &&
     k get clusterpolicy pk3s-audit-require-workload-labels >/dev/null 2>&1; then
    record_ok "Productive K3S Kyverno audit policies exist"
  else
    record_warn "one or more Productive K3S Kyverno audit policies are missing"
  fi
  safe_run k get policyreports -A 2>/dev/null || true
}

#!/usr/bin/env bash

pk3s_addon_validate() {
  local namespace="${PK3S_TRIVY_OPERATOR_NAMESPACE:-trivy-system}"
  info "Checking Trivy Operator"
  if ! k get namespace "${namespace}" >/dev/null 2>&1; then
    info "Trivy Operator is not installed; skipping Trivy-specific checks"
    return
  fi

  check_namespace_rollup "${namespace}" "Trivy Operator"
  if k get crd vulnerabilityreports.aquasecurity.github.io >/dev/null 2>&1; then
    record_ok "Trivy Operator vulnerability report CRD exists"
  else
    record_warn "Trivy Operator vulnerability report CRD is missing"
  fi
  safe_run k get vulnerabilityreports -A 2>/dev/null || true
  safe_run k get configauditreports -A 2>/dev/null || true
}

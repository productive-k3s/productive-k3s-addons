#!/usr/bin/env bash

pk3s_addon_validate() {
  info "Checking kubent"
  if ! k get namespace pk3s-kubent >/dev/null 2>&1; then
    info "kubent is not installed; skipping kubent-specific checks"
    return 0
  fi

  check_namespace_rollup "pk3s-kubent" "kubent"

  if k get clusterrole pk3s-kubent-readonly >/dev/null 2>&1; then
    record_ok "kubent read-only ClusterRole exists"
  else
    record_warn "kubent read-only ClusterRole is missing"
  fi

  if k get job pk3s-kubent-scan -n pk3s-kubent >/dev/null 2>&1; then
    record_ok "kubent scan Job exists"
    safe_run k logs -n pk3s-kubent job/pk3s-kubent-scan --tail=40 || true
  else
    record_warn "kubent scan Job is missing"
  fi
}

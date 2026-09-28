#!/usr/bin/env bash

pk3s_addon_validate() {
  info "Checking Popeye"
  if ! k get namespace pk3s-popeye >/dev/null 2>&1; then
    info "Popeye is not installed; skipping Popeye-specific checks"
    return 0
  fi

  check_namespace_rollup "pk3s-popeye" "Popeye"

  if k get clusterrole pk3s-popeye-readonly >/dev/null 2>&1; then
    record_ok "Popeye read-only ClusterRole exists"
  else
    record_warn "Popeye read-only ClusterRole is missing"
  fi

  if k get job pk3s-popeye-scan -n pk3s-popeye >/dev/null 2>&1; then
    record_ok "Popeye scan Job exists"
    safe_run k logs -n pk3s-popeye job/pk3s-popeye-scan --tail=40 || true
  else
    record_warn "Popeye scan Job is missing"
  fi
}

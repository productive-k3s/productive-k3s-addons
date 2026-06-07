#!/usr/bin/env bash

pk3s_addon_validate() {
  info "Checking in-cluster registry"
  if ! k get namespace registry >/dev/null 2>&1; then
    info "Registry is not installed; skipping registry-specific checks"
    return 0
  fi

  check_namespace_rollup "registry" "Registry"

  local pvc
  if pvc="$(safe_run k get pvc -n registry 2>/dev/null)"; then
    if printf '%s\n' "$pvc" | awk 'NR>1 && $2 != "Bound" {print}' | grep -q .; then
      record_fail "registry PVC exists but is not Bound"
      printf '%s\n' "$pvc"
    elif printf '%s\n' "$pvc" | awk 'NR>1 {print}' | grep -q .; then
      record_ok "registry PVC is Bound"
    else
      record_warn "no registry PVC found"
    fi
  fi

  if k get ingress registry -n registry >/dev/null 2>&1; then
    record_ok "registry ingress exists"
  else
    record_warn "registry ingress does not exist"
  fi
}

pk3s_registry_validate() {
  pk3s_addon_validate "$@"
}

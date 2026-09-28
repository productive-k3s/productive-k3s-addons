#!/usr/bin/env bash

pk3s_addon_validate() {
  local namespace="${PK3S_GEOSERVER_NAMESPACE:-geoserver}"
  local release_name="${PK3S_GEOSERVER_RELEASE_NAME:-geoserver-cloud}"
  info "Checking GeoServer Cloud"
  if ! k get namespace "${namespace}" >/dev/null 2>&1; then
    info "GeoServer Cloud is not installed; skipping GeoServer-specific checks"
    return
  fi

  check_namespace_rollup "${namespace}" "GeoServer Cloud"
  if k get deployment "${release_name}-gsc-gateway" -n "${namespace}" >/dev/null 2>&1; then
    record_ok "GeoServer Cloud gateway deployment exists"
  else
    record_warn "GeoServer Cloud gateway deployment is missing"
  fi
  if k get service "${release_name}-gsc-acl" -n "${namespace}" >/dev/null 2>&1; then
    record_ok "GeoServer Cloud ACL service exists"
  else
    record_warn "GeoServer Cloud ACL service is missing"
  fi
  if k get statefulset "${release_name}-postgresql" -n "${namespace}" >/dev/null 2>&1; then
    record_ok "GeoServer Cloud pgconfig PostGIS statefulset exists"
  else
    record_warn "GeoServer Cloud pgconfig PostGIS statefulset is missing"
  fi
}

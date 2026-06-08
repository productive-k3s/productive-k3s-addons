#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../scripts/addon-host-runtime.sh"

pk3s_addon_validate() {
  info "Checking Longhorn"
  if ! k get namespace longhorn-system >/dev/null 2>&1; then
    info "Longhorn is not installed; skipping Longhorn-specific checks"
    return
  fi

  if pk3s_service_active_optional iscsid; then
    record_ok "iscsid is active on the host"
  else
    record_warn "iscsid is not active on the host"
  fi

  if [[ -d "${PK3S_LONGHORN_DATA_PATH:-/data}" ]]; then
    record_ok "Longhorn host data path exists (${PK3S_LONGHORN_DATA_PATH:-/data})"
  else
    record_warn "Longhorn host data path is missing (${PK3S_LONGHORN_DATA_PATH:-/data})"
  fi

  check_namespace_rollup "longhorn-system" "Longhorn"

  local volumes
  if volumes="$(safe_run k get volumes.longhorn.io -n longhorn-system 2>/dev/null)"; then
    if printf '%s\n' "$volumes" | awk 'NR>1 {print}' | grep -q .; then
      record_ok "Longhorn volumes API is responding"
      check_longhorn_volume_health
    else
      record_ok "Longhorn is installed but no volumes exist yet"
    fi
  fi

  local node_count
  node_count="$(cluster_node_count)"
  if [[ "$node_count" == "1" ]]; then
    info "Checking Longhorn single-node alignment"

    local default_scs
    default_scs="$(default_storageclasses)"
    if printf '%s\n' "$default_scs" | grep -qx 'longhorn-single'; then
      record_ok "single-node cluster uses longhorn-single as the default StorageClass"
    elif printf '%s\n' "$default_scs" | grep -q .; then
      record_warn "single-node cluster default StorageClass is not longhorn-single"
      printf '%s\n' "$default_scs"
    else
      record_warn "single-node cluster has no default StorageClass set to longhorn-single"
    fi

    local minimal_available
    minimal_available="$(longhorn_setting_value storage-minimal-available-percentage)"
    if [[ -z "$minimal_available" ]]; then
      record_warn "unable to read Longhorn storage-minimal-available-percentage"
    elif [[ "$minimal_available" =~ ^[0-9]+$ ]]; then
      if (( minimal_available <= 10 )); then
        record_ok "Longhorn storage-minimal-available-percentage is single-node friendly (${minimal_available})"
      else
        record_warn "Longhorn storage-minimal-available-percentage may be too aggressive for a single-node dev/lab cluster (${minimal_available})"
      fi
    else
      record_warn "Longhorn storage-minimal-available-percentage is non-numeric (${minimal_available})"
    fi
  fi
}

pk3s_longhorn_validate() {
  pk3s_addon_validate "$@"
}

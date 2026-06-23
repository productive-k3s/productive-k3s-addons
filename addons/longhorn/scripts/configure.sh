#!/usr/bin/env bash

pk3s_addon_configure() {
  local phase="$1"
  local output_file="$2"

  case "${phase}" in
    action)
      local longhorn_action="skip"
      if [[ "${PK3S_ADDON_PRESENT:-n}" == "y" ]]; then
        local reuse_longhorn="y"
        prompt_yesno reuse_longhorn "y" "Longhorn is already present. Leave it unchanged and continue? [optional]"
        if [[ "${reuse_longhorn}" == "y" ]]; then
          longhorn_action="reuse"
        fi
      else
        local install_longhorn="y"
        prompt_yesno install_longhorn "y" "Longhorn is missing. Install it now? [optional]"
        if [[ "${install_longhorn}" == "y" ]]; then
          longhorn_action="install"
        fi
      fi
      write_addon_config_var "${output_file}" "LONGHORN_ACTION" "${longhorn_action}"
      ;;
    details)
      local longhorn_data_path="${LONGHORN_DATA_PATH:-/data}"
      local longhorn_replica_count="${LONGHORN_REPLICA_COUNT:-1}"
      local longhorn_minimal_available_percentage="${LONGHORN_MINIMAL_AVAILABLE_PERCENTAGE:-10}"
      local longhorn_make_default="${LONGHORN_MAKE_DEFAULT:-n}"

      prompt longhorn_data_path "${longhorn_data_path}" "Longhorn data mount path"
      prompt longhorn_replica_count "${longhorn_replica_count}" "Longhorn default replica count (1 for single-node)"
      if [[ "${PK3S_SINGLE_NODE_LONGHORN_MODE:-n}" == "y" ]]; then
        prompt longhorn_minimal_available_percentage "${longhorn_minimal_available_percentage}" "Longhorn storage minimal available percentage (10 is recommended for single-node dev/lab)"
        log "Single-node Longhorn mode is enabled. The bootstrap will create a 'longhorn-single' StorageClass with numberOfReplicas=1."
      fi
      warn "Longhorn host preparation will install open-iscsi, enable iscsid, and ensure the data path exists on this host."
      prompt_yesno longhorn_make_default "${longhorn_make_default}" "Make Longhorn the default StorageClass?"

      write_addon_config_var "${output_file}" "LONGHORN_DATA_PATH" "${longhorn_data_path}"
      write_addon_config_var "${output_file}" "LONGHORN_REPLICA_COUNT" "${longhorn_replica_count}"
      write_addon_config_var "${output_file}" "LONGHORN_MINIMAL_AVAILABLE_PERCENTAGE" "${longhorn_minimal_available_percentage}"
      write_addon_config_var "${output_file}" "LONGHORN_MAKE_DEFAULT" "${longhorn_make_default}"
      ;;
    *)
      err "Unsupported longhorn configure phase: ${phase}"
      exit 1
      ;;
  esac
}

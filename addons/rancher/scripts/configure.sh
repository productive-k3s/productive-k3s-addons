#!/usr/bin/env bash

pk3s_addon_configure() {
  local phase="$1"
  local output_file="$2"

  case "${phase}" in
    action)
      local rancher_action="skip"
      if [[ "${PK3S_ADDON_PRESENT:-n}" == "y" ]]; then
        local reuse_rancher="y"
        prompt_yesno reuse_rancher "y" "Rancher is already present. Leave it unchanged and continue? [optional]"
        if [[ "${reuse_rancher}" == "y" ]]; then
          rancher_action="reuse"
        fi
      else
        local install_rancher="y"
        prompt_yesno install_rancher "y" "Rancher is missing. Install it now? [optional]"
        if [[ "${install_rancher}" == "y" ]]; then
          rancher_action="install"
        fi
      fi
      write_addon_config_var "${output_file}" "RANCHER_ACTION" "${rancher_action}"
      ;;
    details)
      local rancher_host="${RANCHER_HOST:-rancher.example.local}"
      local admin_pass="${ADMIN_PASS:-admin}"

      prompt rancher_host "${rancher_host}" "Rancher hostname (DNS name)"
      prompt admin_pass "${admin_pass}" "Rancher bootstrap password"

      write_addon_config_var "${output_file}" "RANCHER_HOST" "${rancher_host}"
      write_addon_config_var "${output_file}" "ADMIN_PASS" "${admin_pass}"
      ;;
    *)
      err "Unsupported rancher configure phase: ${phase}"
      exit 1
      ;;
  esac
}

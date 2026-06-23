#!/usr/bin/env bash

pk3s_addon_configure() {
  local phase="$1"
  local output_file="$2"

  case "${phase}" in
    action)
      local cert_manager_action="skip"
      if [[ "${PK3S_ADDON_PRESENT:-n}" == "y" ]]; then
        cert_manager_action="reuse"
      elif [[ "${PK3S_CERT_MANAGER_REQUIRED:-n}" == "y" ]]; then
        local install_cert_manager="y"
        prompt_yesno install_cert_manager "y" "cert-manager is missing. Install it now? [required for TLS-dependent installs]"
        [[ "${install_cert_manager}" == "y" ]] || { err "Skipping cert-manager would leave TLS-dependent installs unsupported."; exit 1; }
        cert_manager_action="install"
      fi

      write_addon_config_var "${output_file}" "CERT_MANAGER_ACTION" "${cert_manager_action}"
      ;;
    details)
      ;;
    *)
      err "Unsupported cert-manager configure phase: ${phase}"
      exit 1
      ;;
  esac
}

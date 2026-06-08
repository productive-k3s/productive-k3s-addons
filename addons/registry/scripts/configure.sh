#!/usr/bin/env bash

pk3s_addon_configure() {
  local phase="$1"
  local output_file="$2"

  case "${phase}" in
    action)
      local registry_action="skip"
      if [[ "${PK3S_ADDON_PRESENT:-n}" == "y" ]]; then
        local reuse_registry="y"
        prompt_yesno reuse_registry "y" "The in-cluster registry is already present. Leave it unchanged and continue? [optional]"
        if [[ "${reuse_registry}" == "y" ]]; then
          registry_action="reuse"
        fi
      else
        local install_registry="y"
        prompt_yesno install_registry "y" "The in-cluster registry is missing. Install it now? [optional]"
        if [[ "${install_registry}" == "y" ]]; then
          registry_action="install"
        fi
      fi
      write_addon_config_var "${output_file}" "REGISTRY_ACTION" "${registry_action}"
      ;;
    details)
      local registry_host="${REGISTRY_HOST:-registry.example.local}"
      local registry_size="${REGISTRY_SIZE:-20Gi}"
      local registry_storage_class="${REGISTRY_STORAGE_CLASS:-}"
      local registry_auth_enabled="${REGISTRY_AUTH_ENABLED:-n}"
      local registry_auth_user="${REGISTRY_AUTH_USER:-registry}"
      local registry_auth_password="${REGISTRY_AUTH_PASSWORD:-change-me}"
      local registry_manage_local_hosts="${REGISTRY_MANAGE_LOCAL_HOSTS:-n}"
      local registry_trust_docker="${REGISTRY_TRUST_DOCKER:-n}"

      prompt registry_host "${registry_host}" "Registry hostname (DNS name)"
      prompt registry_size "${registry_size}" "Registry PVC size"
      prompt registry_storage_class "${registry_storage_class}" "Registry StorageClass (blank uses cluster default)"
      prompt_yesno registry_auth_enabled "${registry_auth_enabled}" "Do you want to enable basic auth on the in-cluster registry?"
      if [[ "${registry_auth_enabled}" == "y" ]]; then
        prompt registry_auth_user "${registry_auth_user}" "Registry username"
        prompt registry_auth_password "${registry_auth_password}" "Registry password"
      fi
      if [[ "${PK3S_ALLOW_HOST_LOCAL_CHANGES:-n}" == "y" ]]; then
        registry_manage_local_hosts="${REGISTRY_MANAGE_LOCAL_HOSTS:-y}"
        prompt_yesno registry_manage_local_hosts "${registry_manage_local_hosts}" "Update local /etc/hosts on this machine for the registry hostname?"
        if [[ "${PK3S_TLS_SOURCE:-secret}" == "secret" ]]; then
          prompt_yesno registry_trust_docker "${registry_trust_docker}" "Install local Docker trust for the registry certificate on this machine?"
        else
          registry_trust_docker="n"
        fi
      else
        registry_manage_local_hosts="n"
        registry_trust_docker="n"
      fi

      write_addon_config_var "${output_file}" "REGISTRY_HOST" "${registry_host}"
      write_addon_config_var "${output_file}" "REGISTRY_SIZE" "${registry_size}"
      write_addon_config_var "${output_file}" "REGISTRY_STORAGE_CLASS" "${registry_storage_class}"
      write_addon_config_var "${output_file}" "REGISTRY_AUTH_ENABLED" "${registry_auth_enabled}"
      write_addon_config_var "${output_file}" "REGISTRY_AUTH_USER" "${registry_auth_user}"
      write_addon_config_var "${output_file}" "REGISTRY_AUTH_PASSWORD" "${registry_auth_password}"
      write_addon_config_var "${output_file}" "REGISTRY_MANAGE_LOCAL_HOSTS" "${registry_manage_local_hosts}"
      write_addon_config_var "${output_file}" "REGISTRY_TRUST_DOCKER" "${registry_trust_docker}"
      ;;
    *)
      err "Unsupported registry configure phase: ${phase}"
      exit 1
      ;;
  esac
}

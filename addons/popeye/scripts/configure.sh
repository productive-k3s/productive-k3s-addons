#!/usr/bin/env bash

pk3s_addon_configure() {
  local phase="$1"
  local output_file="$2"

  case "${phase}" in
    action)
      write_addon_config_var "${output_file}" "POPEYE_ACTION" "install"
      ;;
    details)
      write_addon_config_var "${output_file}" "POPEYE_NAMESPACE" "${PK3S_POPEYE_NAMESPACE:-pk3s-popeye}"
      write_addon_config_var "${output_file}" "POPEYE_IMAGE" "${PK3S_POPEYE_IMAGE:-quay.io/derailed/popeye:v0.22.1}"
      ;;
    *)
      err "Unsupported popeye configure phase: ${phase}"
      exit 1
      ;;
  esac
}

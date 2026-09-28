#!/usr/bin/env bash

pk3s_addon_configure() {
  local phase="$1"
  local output_file="$2"

  case "${phase}" in
    action)
      write_addon_config_var "${output_file}" "KUBENT_ACTION" "install"
      ;;
    details)
      write_addon_config_var "${output_file}" "KUBENT_NAMESPACE" "${PK3S_KUBENT_NAMESPACE:-pk3s-kubent}"
      write_addon_config_var "${output_file}" "KUBENT_IMAGE" "${PK3S_KUBENT_IMAGE:-ghcr.io/doitintl/kube-no-trouble:0.7.3}"
      ;;
    *)
      err "Unsupported kubent configure phase: ${phase}"
      exit 1
      ;;
  esac
}

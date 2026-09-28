#!/usr/bin/env bash

pk3s_addon_configure() {
  local phase="$1"
  local output_file="$2"

  case "${phase}" in
    action)
      write_addon_config_var "${output_file}" "ARGOCD_ACTION" "install"
      ;;
    details)
      write_addon_config_var "${output_file}" "ARGOCD_NAMESPACE" "${ARGOCD_NAMESPACE:-argocd}"
      write_addon_config_var "${output_file}" "ARGOCD_CHART_VERSION" "${ARGOCD_CHART_VERSION:-10.8.1}"
      write_addon_config_var "${output_file}" "ARGOCD_HOST" "${ARGOCD_HOST:-argocd.k3s.lab.internal}"
      write_addon_config_var "${output_file}" "ARGOCD_INGRESS_ENABLED" "${ARGOCD_INGRESS_ENABLED:-n}"
      ;;
    *)
      err "Unsupported argocd configure phase: ${phase}"
      exit 1
      ;;
  esac
}

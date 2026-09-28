#!/usr/bin/env bash

pk3s_addon_configure() {
  local phase="$1"
  local output_file="$2"

  case "${phase}" in
    action)
      write_addon_config_var "${output_file}" "TRIVY_OPERATOR_ACTION" "install"
      ;;
    details)
      write_addon_config_var "${output_file}" "TRIVY_OPERATOR_NAMESPACE" "${TRIVY_OPERATOR_NAMESPACE:-trivy-system}"
      write_addon_config_var "${output_file}" "TRIVY_OPERATOR_CHART_VERSION" "${TRIVY_OPERATOR_CHART_VERSION:-0.35.0}"
      ;;
    *)
      err "Unsupported trivy-operator configure phase: ${phase}"
      exit 1
      ;;
  esac
}

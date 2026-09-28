#!/usr/bin/env bash

pk3s_addon_configure() {
  local phase="$1"
  local output_file="$2"

  case "${phase}" in
    action)
      write_addon_config_var "${output_file}" "KYVERNO_ACTION" "install"
      ;;
    details)
      write_addon_config_var "${output_file}" "KYVERNO_NAMESPACE" "${KYVERNO_NAMESPACE:-kyverno}"
      write_addon_config_var "${output_file}" "KYVERNO_CHART_VERSION" "${KYVERNO_CHART_VERSION:-3.9.0}"
      write_addon_config_var "${output_file}" "KYVERNO_VALIDATION_FAILURE_ACTION" "${KYVERNO_VALIDATION_FAILURE_ACTION:-Audit}"
      ;;
    *)
      err "Unsupported kyverno configure phase: ${phase}"
      exit 1
      ;;
  esac
}

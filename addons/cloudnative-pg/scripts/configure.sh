#!/usr/bin/env bash

pk3s_addon_configure() {
  local phase="$1"
  local output_file="$2"

  case "${phase}" in
    action)
      write_addon_config_var "${output_file}" "CLOUDNATIVE_PG_ACTION" "install"
      ;;
    details)
      write_addon_config_var "${output_file}" "CLOUDNATIVE_PG_CHART_VERSION" "${CLOUDNATIVE_PG_CHART_VERSION:-0.29.0}"
      write_addon_config_var "${output_file}" "CNPG_CLUSTER_NAME" "${CNPG_CLUSTER_NAME:-pk3s-postgres}"
      write_addon_config_var "${output_file}" "CNPG_DATABASE_NAMESPACE" "${CNPG_DATABASE_NAMESPACE:-database}"
      write_addon_config_var "${output_file}" "CNPG_STORAGE_SIZE" "${CNPG_STORAGE_SIZE:-10Gi}"
      ;;
    *)
      err "Unsupported cloudnative-pg configure phase: ${phase}"
      exit 1
      ;;
  esac
}

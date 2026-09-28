#!/usr/bin/env bash

pk3s_addon_configure() {
  local phase="$1"
  local output_file="$2"

  case "${phase}" in
    action)
      write_addon_config_var "${output_file}" "GEOSERVER_CLOUD_ACTION" "install"
      ;;
    details)
      write_addon_config_var "${output_file}" "GEOSERVER_NAMESPACE" "${GEOSERVER_NAMESPACE:-geoserver}"
      write_addon_config_var "${output_file}" "GEOSERVER_RELEASE_NAME" "${GEOSERVER_RELEASE_NAME:-geoserver-cloud}"
      write_addon_config_var "${output_file}" "GEOSERVER_CHART" "camptocamp/geoservercloud:3.0.1"
      write_addon_config_var "${output_file}" "GEOSERVER_PROFILE" "standalone,pgconfig,acl"
      ;;
    *)
      err "Unsupported geoserver-cloud configure phase: ${phase}"
      exit 1
      ;;
  esac
}

#!/usr/bin/env bash

pk3s_addon_configure() {
  local phase="$1"
  local output_file="$2"

  case "${phase}" in
    action)
      write_addon_config_var "${output_file}" "NGINX_ACTION" "install"
      ;;
    details)
      ;;
    *)
      printf '[ERROR] Unsupported nginx configure phase: %s\n' "${phase}" >&2
      exit 1
      ;;
  esac
}

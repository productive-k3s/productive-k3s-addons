#!/usr/bin/env bash
set -euo pipefail
pk3s_addon_configure() { :; }
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then pk3s_addon_configure "$@"; fi

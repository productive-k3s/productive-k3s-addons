#!/usr/bin/env bash
set -euo pipefail
ADDON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_BIN="${PK3S_HELM_BIN:-helm}"
VALUES_FILE="${ADDON_SCRIPT_DIR}/../values.yaml"
RELEASE_NAME="${PK3S_ADDON_RELEASE_NAME:-openship-whoami-redis-web}"
NAMESPACE="${PK3S_ADDON_NAMESPACE:-pk3s-openship-whoami-redis}"

pk3s_addon_install() {
  local chart_dir chart_archive actual_digest
  chart_dir="$(mktemp -d)"
  trap 'rm -rf "${chart_dir}"' RETURN
  "${HELM_BIN}" pull "application" --repo "https://stakater.github.io/stakater-charts" --version "9.3.2" --destination "${chart_dir}"
  chart_archive="${chart_dir}/application-9.3.2.tgz"
  actual_digest="sha256:$(sha256sum "${chart_archive}" | awk '{print $1}')"
  if [[ "${actual_digest}" != "sha256:1c17fecf71c676868282a74462d82c7b252b244f2a2a3cf8f56b2825298f59c0" ]]; then
    echo "Chart digest mismatch for application 9.3.2: expected sha256:1c17fecf71c676868282a74462d82c7b252b244f2a2a3cf8f56b2825298f59c0, got ${actual_digest}" >&2
    return 1
  fi
  "${HELM_BIN}" upgrade --install "${RELEASE_NAME}" "${chart_archive}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    -f "${VALUES_FILE}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then pk3s_addon_install "$@"; fi

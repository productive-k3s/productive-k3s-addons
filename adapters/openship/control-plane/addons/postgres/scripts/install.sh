#!/usr/bin/env bash
set -euo pipefail
ADDON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_BIN="${PK3S_HELM_BIN:-helm}"
VALUES_FILE="${ADDON_SCRIPT_DIR}/../values.yaml"
RELEASE_NAME="${PK3S_ADDON_RELEASE_NAME:-openship-control-plane-postgres}"
NAMESPACE="${PK3S_ADDON_NAMESPACE:-pk3s-openship-control-plane}"

pk3s_addon_install() {
  local chart_dir chart_archive actual_digest
  chart_dir="$(mktemp -d)"
  trap 'rm -rf "${chart_dir}"' RETURN
  "${HELM_BIN}" pull "postgresql" --repo "https://charts.bitnami.com/bitnami" --version "18.12.4" --destination "${chart_dir}"
  chart_archive="${chart_dir}/postgresql-18.12.4.tgz"
  actual_digest="sha256:$(sha256sum "${chart_archive}" | awk '{print $1}')"
  if [[ "${actual_digest}" != "sha256:cdea1be659dd2c9b573adaee286b426911bcc4ddd4d7e0111df65309e38669fb" ]]; then
    echo "Chart digest mismatch for postgresql 18.12.4: expected sha256:cdea1be659dd2c9b573adaee286b426911bcc4ddd4d7e0111df65309e38669fb, got ${actual_digest}" >&2
    return 1
  fi
  "${HELM_BIN}" upgrade --install "${RELEASE_NAME}" "${chart_archive}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    -f "${VALUES_FILE}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then pk3s_addon_install "$@"; fi

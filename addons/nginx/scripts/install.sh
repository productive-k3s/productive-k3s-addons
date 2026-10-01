#!/usr/bin/env bash
set -euo pipefail

ADDON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_BIN="${PK3S_HELM_BIN:-helm}"
VALUES_FILE="${ADDON_SCRIPT_DIR}/../values.yaml"
RELEASE_NAME="${PK3S_ADDON_RELEASE_NAME:-pk3s-nginx}"
NAMESPACE="${PK3S_ADDON_NAMESPACE:-pk3s-nginx}"
NGINX_CHART_VERSION="${PK3S_NGINX_CHART_VERSION:-25.2.1}"

pk3s_addon_install() {
  "${HELM_BIN}" repo add bitnami https://charts.bitnami.com/bitnami >/dev/null 2>&1 || true
  "${HELM_BIN}" repo update >/dev/null
  "${HELM_BIN}" upgrade --install "${RELEASE_NAME}" bitnami/nginx \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --version "${NGINX_CHART_VERSION}" \
    -f "${VALUES_FILE}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  pk3s_addon_install "$@"
fi

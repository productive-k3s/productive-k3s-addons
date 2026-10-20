#!/usr/bin/env bash
set -euo pipefail

ADDON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELM_BIN="${PK3S_HELM_BIN:-helm}"
VALUES_FILE="${ADDON_SCRIPT_DIR}/../values.yaml"
RELEASE_NAME="${PK3S_ADDON_RELEASE_NAME:-pk3s-nginx}"
NAMESPACE="${PK3S_ADDON_NAMESPACE:-pk3s-nginx}"
NGINX_CHART_VERSION="${PK3S_NGINX_CHART_VERSION:-25.2.1}"
NGINX_CHART_SHA256="${PK3S_NGINX_CHART_SHA256:-a31c7a2881593607945741f11a49525958ca3cdee91d70d19323c2bd7f8d8867}"

pk3s_addon_install() {
  "${HELM_BIN}" repo add bitnami https://charts.bitnami.com/bitnami >/dev/null 2>&1 || true
  "${HELM_BIN}" repo update >/dev/null

  local chart_dir chart_archive chart_actual_sha256
  chart_dir="$(mktemp -d)"
  chart_archive="${chart_dir}/nginx-${NGINX_CHART_VERSION}.tgz"
  trap 'rm -rf "${chart_dir}"' RETURN

  "${HELM_BIN}" pull bitnami/nginx --version "${NGINX_CHART_VERSION}" --destination "${chart_dir}"
  chart_actual_sha256="$(sha256sum "${chart_archive}" | awk '{print $1}')"
  if [[ "${chart_actual_sha256}" != "${NGINX_CHART_SHA256}" ]]; then
    printf '[ERROR] nginx chart digest mismatch: expected %s, got %s\n' "${NGINX_CHART_SHA256}" "${chart_actual_sha256}" >&2
    return 1
  fi

  "${HELM_BIN}" upgrade --install "${RELEASE_NAME}" "${chart_archive}" --namespace "${NAMESPACE}" --create-namespace -f "${VALUES_FILE}"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  pk3s_addon_install "$@"
fi

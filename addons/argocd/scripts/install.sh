#!/usr/bin/env bash
set -euo pipefail

ADDON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ADDON_SCRIPT_DIR}/../../../scripts/addon-host-runtime.sh"
source "${ADDON_SCRIPT_DIR}/../../../scripts/verified-helm-chart.sh"

KUBECTL_BIN="${PK3S_KUBECTL_BIN:-kubectl}"
HELM_BIN="${PK3S_HELM_BIN:-helm}"
VALUES_FILE="${ADDON_SCRIPT_DIR}/../values.yaml"
ARGOCD_NAMESPACE="${PK3S_ARGOCD_NAMESPACE:-argocd}"
ARGOCD_CHART_VERSION="${PK3S_ARGOCD_CHART_VERSION:-10.8.1}"
ARGOCD_CHART_SHA256="${PK3S_ARGOCD_CHART_SHA256:-7f71e5af5eac0eb73bd79faf6fca60a644740ee4773d17f5225786ead265b064}"
ARGOCD_HOST="${PK3S_ARGOCD_HOST:-argocd.k3s.lab.internal}"
ARGOCD_INGRESS_ENABLED="${PK3S_ARGOCD_INGRESS_ENABLED:-n}"
ARGOCD_TLS_ENABLED="${PK3S_ARGOCD_TLS_ENABLED:-y}"
ARGOCD_TLS_SECRET="${PK3S_ARGOCD_TLS_SECRET:-argocd-server-tls}"
ARGOCD_ADMIN_PASSWORD_HASH="${PK3S_ARGOCD_ADMIN_PASSWORD_HASH:-}"
INGRESS_CLASS_NAME="${PK3S_INGRESS_CLASS_NAME:-traefik}"

kctl() {
  if [[ "${PK3S_KUBECTL_MODE:-kubectl}" == "kubectl" ]]; then
    "${KUBECTL_BIN}" "$@"
  elif declare -F pk3s_addon_kubectl >/dev/null 2>&1; then
    pk3s_addon_kubectl "$@"
  elif declare -F pk3s_runtime_kubectl >/dev/null 2>&1; then
    pk3s_runtime_kubectl "$@"
  else
    "${KUBECTL_BIN}" "$@"
  fi
}

pk3s_addon_install() {
  local helm_args chart_dir chart_archive
  chart_dir="$(mktemp -d)"
  trap 'rm -rf "${chart_dir}"' RETURN
  chart_archive="$(pk3s_pull_verified_helm_chart "${HELM_BIN}" argo https://argoproj.github.io/argo-helm argo-cd "${ARGOCD_CHART_VERSION}" "${ARGOCD_CHART_SHA256}" "${chart_dir}")"
  helm_args=(
    upgrade --install argocd "${chart_archive}"
    --namespace "${ARGOCD_NAMESPACE}"
    -f "${VALUES_FILE}"
    --set "configs.params.server.insecure=true"
  )

  kctl create namespace "${ARGOCD_NAMESPACE}" >/dev/null 2>&1 || true

  if [[ "${ARGOCD_INGRESS_ENABLED}" == "y" ]]; then
    helm_args+=(
      --set "server.ingress.enabled=true"
      --set "server.ingress.ingressClassName=${INGRESS_CLASS_NAME}"
      --set "server.ingress.hostname=${ARGOCD_HOST}"
    )
    if [[ "${ARGOCD_TLS_ENABLED}" == "y" ]]; then
      helm_args+=(--set "server.ingress.tls=true" --set "server.ingress.extraTls[0].hosts[0]=${ARGOCD_HOST}" --set "server.ingress.extraTls[0].secretName=${ARGOCD_TLS_SECRET}")
    fi
  fi
  if [[ -n "${ARGOCD_ADMIN_PASSWORD_HASH}" ]]; then
    helm_args+=(--set "configs.secret.argocdServerAdminPassword=${ARGOCD_ADMIN_PASSWORD_HASH}")
  fi

  "${HELM_BIN}" "${helm_args[@]}"
  kctl -n "${ARGOCD_NAMESPACE}" rollout status deployment/argocd-server --timeout=10m
  kctl -n "${ARGOCD_NAMESPACE}" rollout status deployment/argocd-repo-server --timeout=10m
  kctl -n "${ARGOCD_NAMESPACE}" rollout status deployment/argocd-application-controller --timeout=10m || true
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  pk3s_addon_install "$@"
fi

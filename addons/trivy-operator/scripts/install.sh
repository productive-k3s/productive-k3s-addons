#!/usr/bin/env bash
set -euo pipefail

ADDON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ADDON_SCRIPT_DIR}/../../../scripts/addon-host-runtime.sh"

KUBECTL_BIN="${PK3S_KUBECTL_BIN:-kubectl}"
HELM_BIN="${PK3S_HELM_BIN:-helm}"
TRIVY_NAMESPACE="${PK3S_TRIVY_OPERATOR_NAMESPACE:-trivy-system}"
TRIVY_CHART_VERSION="${PK3S_TRIVY_OPERATOR_CHART_VERSION:-0.35.0}"

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
  kctl create namespace "${TRIVY_NAMESPACE}" >/dev/null 2>&1 || true
  "${HELM_BIN}" repo add trivy-operator https://aquasecurity.github.io/helm-charts >/dev/null 2>&1 || true
  "${HELM_BIN}" repo update >/dev/null
  "${HELM_BIN}" upgrade --install trivy-operator trivy-operator/trivy-operator \
    --namespace "${TRIVY_NAMESPACE}" \
    --version "${TRIVY_CHART_VERSION}" \
    --set operator.builtInTrivyServer=false
  kctl -n "${TRIVY_NAMESPACE}" rollout status deployment/trivy-operator --timeout=10m
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  pk3s_addon_install "$@"
fi

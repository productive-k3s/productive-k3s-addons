#!/usr/bin/env bash
set -euo pipefail

ADDON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ADDON_SCRIPT_DIR}/../../../scripts/addon-host-runtime.sh"
source "${ADDON_SCRIPT_DIR}/../../../scripts/verified-helm-chart.sh"

KUBECTL_BIN="${PK3S_KUBECTL_BIN:-kubectl}"
HELM_BIN="${PK3S_HELM_BIN:-helm}"
VALUES_FILE="${ADDON_SCRIPT_DIR}/../values.yaml"
TRIVY_NAMESPACE="${PK3S_TRIVY_OPERATOR_NAMESPACE:-trivy-system}"
TRIVY_CHART_VERSION="${PK3S_TRIVY_OPERATOR_CHART_VERSION:-0.35.0}"
TRIVY_CHART_SHA256="${PK3S_TRIVY_OPERATOR_CHART_SHA256:-c9bbd17603e808f7d9eac3d02a826a717164888bd4a045a4178efcfc2ee22a6b}"

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
  local chart_dir chart_archive
  chart_dir="$(mktemp -d)"
  trap 'rm -rf "${chart_dir}"' RETURN
  chart_archive="$(pk3s_pull_verified_helm_chart "${HELM_BIN}" trivy-operator https://aquasecurity.github.io/helm-charts trivy-operator "${TRIVY_CHART_VERSION}" "${TRIVY_CHART_SHA256}" "${chart_dir}")"

  kctl create namespace "${TRIVY_NAMESPACE}" >/dev/null 2>&1 || true
  "${HELM_BIN}" upgrade --install trivy-operator "${chart_archive}" \
    --namespace "${TRIVY_NAMESPACE}" \
    -f "${VALUES_FILE}" \
    --set operator.builtInTrivyServer=false
  kctl -n "${TRIVY_NAMESPACE}" rollout status deployment/trivy-operator --timeout=10m
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  pk3s_addon_install "$@"
fi

#!/usr/bin/env bash
set -euo pipefail

ADDON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ADDON_SCRIPT_DIR}/../../../scripts/addon-host-runtime.sh"
VERIFIED_HELM_CHART_SCRIPT="${ADDON_SCRIPT_DIR}/verified-helm-chart.sh"
[[ -f "${VERIFIED_HELM_CHART_SCRIPT}" ]] || VERIFIED_HELM_CHART_SCRIPT="${ADDON_SCRIPT_DIR}/../../../scripts/verified-helm-chart.sh"
source "${VERIFIED_HELM_CHART_SCRIPT}"

KUBECTL_BIN="${PK3S_KUBECTL_BIN:-kubectl}"
HELM_BIN="${PK3S_HELM_BIN:-helm}"
VALUES_FILE="${ADDON_SCRIPT_DIR}/../values.yaml"
CNPG_OPERATOR_NAMESPACE="${PK3S_CNPG_OPERATOR_NAMESPACE:-cnpg-system}"
CNPG_CHART_VERSION="${PK3S_CLOUDNATIVE_PG_CHART_VERSION:-0.29.0}"
CNPG_CHART_SHA256="${PK3S_CLOUDNATIVE_PG_CHART_SHA256:-668e065ff53508d58238788fd35b355a925060843629a951df0e6a9362e6d32f}"
CNPG_DATABASE_NAMESPACE="${PK3S_CNPG_DATABASE_NAMESPACE:-database}"
CNPG_CLUSTER_NAME="${PK3S_CNPG_CLUSTER_NAME:-pk3s-postgres}"
CNPG_DATABASE_NAME="${PK3S_CNPG_DATABASE_NAME:-app}"
CNPG_APP_USER="${PK3S_CNPG_APP_USER:-app}"
CNPG_INSTANCES="${PK3S_CNPG_INSTANCES:-1}"
CNPG_STORAGE_SIZE="${PK3S_CNPG_STORAGE_SIZE:-10Gi}"
CNPG_STORAGE_CLASS="${PK3S_CNPG_STORAGE_CLASS:-}"
CNPG_CREATE_CLUSTER="${PK3S_CNPG_CREATE_CLUSTER:-y}"

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

storage_class_block() {
  if [[ -n "${CNPG_STORAGE_CLASS}" ]]; then
    printf '    storageClass: %s\n' "${CNPG_STORAGE_CLASS}"
  fi
}

wait_cnpg_cluster_ready() {
  local deadline=$((SECONDS + 900))
  while (( SECONDS < deadline )); do
    if kctl -n "${CNPG_DATABASE_NAMESPACE}" get cluster "${CNPG_CLUSTER_NAME}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -qx 'True'; then
      return 0
    fi
    sleep 10
  done
  printf 'timed out waiting for CloudNativePG cluster readiness: %s/%s\n' "${CNPG_DATABASE_NAMESPACE}" "${CNPG_CLUSTER_NAME}" >&2
  return 1
}

pk3s_addon_install() {
  local chart_dir chart_archive
  chart_dir="$(mktemp -d)"
  trap 'rm -rf "${chart_dir}"' RETURN
  chart_archive="$(pk3s_pull_verified_helm_chart "${HELM_BIN}" cnpg https://cloudnative-pg.github.io/charts cloudnative-pg "${CNPG_CHART_VERSION}" "${CNPG_CHART_SHA256}" "${chart_dir}")"

  kctl create namespace "${CNPG_OPERATOR_NAMESPACE}" >/dev/null 2>&1 || true
  "${HELM_BIN}" upgrade --install cloudnative-pg "${chart_archive}" \
    --namespace "${CNPG_OPERATOR_NAMESPACE}" \
    -f "${VALUES_FILE}"
  kctl -n "${CNPG_OPERATOR_NAMESPACE}" rollout status deployment/cloudnative-pg --timeout=10m

  if [[ "${CNPG_CREATE_CLUSTER}" != "y" ]]; then
    return 0
  fi

  kctl create namespace "${CNPG_DATABASE_NAMESPACE}" >/dev/null 2>&1 || true
  kctl apply -f - <<MANIFEST
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: ${CNPG_CLUSTER_NAME}
  namespace: ${CNPG_DATABASE_NAMESPACE}
  labels:
    app.kubernetes.io/name: cloudnative-pg
    app.kubernetes.io/part-of: productive-k3s
spec:
  instances: ${CNPG_INSTANCES}
  bootstrap:
    initdb:
      database: ${CNPG_DATABASE_NAME}
      owner: ${CNPG_APP_USER}
  storage:
    size: ${CNPG_STORAGE_SIZE}
$(storage_class_block)
MANIFEST
  wait_cnpg_cluster_ready
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  pk3s_addon_install "$@"
fi

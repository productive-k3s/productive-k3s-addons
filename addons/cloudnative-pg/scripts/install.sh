#!/usr/bin/env bash
set -euo pipefail

ADDON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ADDON_SCRIPT_DIR}/../../../scripts/addon-host-runtime.sh"

KUBECTL_BIN="${PK3S_KUBECTL_BIN:-kubectl}"
HELM_BIN="${PK3S_HELM_BIN:-helm}"
CNPG_OPERATOR_NAMESPACE="${PK3S_CNPG_OPERATOR_NAMESPACE:-cnpg-system}"
CNPG_CHART_VERSION="${PK3S_CLOUDNATIVE_PG_CHART_VERSION:-0.29.0}"
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
  kctl create namespace "${CNPG_OPERATOR_NAMESPACE}" >/dev/null 2>&1 || true
  "${HELM_BIN}" repo add cnpg https://cloudnative-pg.github.io/charts >/dev/null 2>&1 || true
  "${HELM_BIN}" repo update >/dev/null
  "${HELM_BIN}" upgrade --install cloudnative-pg cnpg/cloudnative-pg \
    --namespace "${CNPG_OPERATOR_NAMESPACE}" \
    --version "${CNPG_CHART_VERSION}"
  kctl -n "${CNPG_OPERATOR_NAMESPACE}" rollout status deployment/cloudnative-pg --timeout=10m

  if [[ "${CNPG_CREATE_CLUSTER}" != "y" ]]; then
    return 0
  fi

  kctl create namespace "${CNPG_DATABASE_NAMESPACE}" >/dev/null 2>&1 || true
  kctl apply -f - <<EOF
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
EOF
  wait_cnpg_cluster_ready
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  pk3s_addon_install "$@"
fi

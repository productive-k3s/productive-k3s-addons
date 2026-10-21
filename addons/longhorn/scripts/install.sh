#!/usr/bin/env bash
set -euo pipefail

ADDON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ADDON_SCRIPT_DIR}/../../../scripts/addon-host-runtime.sh"
VERIFIED_HELM_CHART_SCRIPT="${ADDON_SCRIPT_DIR}/verified-helm-chart.sh"
[[ -f "${VERIFIED_HELM_CHART_SCRIPT}" ]] || VERIFIED_HELM_CHART_SCRIPT="${ADDON_SCRIPT_DIR}/../../../scripts/verified-helm-chart.sh"
source "${VERIFIED_HELM_CHART_SCRIPT}"

KUBECTL_BIN="${PK3S_KUBECTL_BIN:-kubectl}"
HELM_BIN="${PK3S_HELM_BIN:-helm}"
KUBECTL_MODE="${PK3S_KUBECTL_MODE:-kubectl}"
LONGHORN_VERSION="${PK3S_LONGHORN_VERSION:-v1.11.1}"
LONGHORN_CHART_SHA256="${PK3S_LONGHORN_CHART_SHA256:-a93f60052e5e6e308d07e93fb3ecc0e4d336bbd323b725f0689df2e4d695245b}"
LONGHORN_VALUES_FILE="${PK3S_LONGHORN_VALUES_FILE:-${ADDON_SCRIPT_DIR}/../values.yaml}"
LONGHORN_DATA_PATH="${PK3S_LONGHORN_DATA_PATH:-/data}"
LONGHORN_REPLICA_COUNT="${PK3S_LONGHORN_REPLICA_COUNT:-1}"
LONGHORN_SINGLE_NODE_MODE="${PK3S_LONGHORN_SINGLE_NODE_MODE:-n}"
LONGHORN_MINIMAL_AVAILABLE_PERCENTAGE="${PK3S_LONGHORN_MINIMAL_AVAILABLE_PERCENTAGE:-10}"
LONGHORN_MAKE_DEFAULT="${PK3S_LONGHORN_MAKE_DEFAULT:-n}"

if [[ ! "${LONGHORN_MINIMAL_AVAILABLE_PERCENTAGE}" =~ ^[0-9]+$ ]]; then
  pk3s_runtime_warn "Invalid Longhorn storage minimal available percentage '${LONGHORN_MINIMAL_AVAILABLE_PERCENTAGE}', using default: 10"
  LONGHORN_MINIMAL_AVAILABLE_PERCENTAGE="10"
fi

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
  pk3s_ensure_packages_optional "Longhorn" open-iscsi jq
  pk3s_enable_service_optional iscsid
  pk3s_runtime_warn "Longhorn storage path '${LONGHORN_DATA_PATH}' will be created if missing."
  pk3s_runtime_warn "This add-on will not format or mount disks. Prepare dedicated mounted storage yourself if you need it."
  pk3s_ensure_directory_optional "${LONGHORN_DATA_PATH}"

  kctl create namespace longhorn-system >/dev/null 2>&1 || true
  chart_dir="$(mktemp -d)"
  trap "rm -rf '${chart_dir}'" EXIT
  chart_archive="$(pk3s_pull_verified_helm_chart "${HELM_BIN}" longhorn https://charts.longhorn.io longhorn "${LONGHORN_VERSION}" "${LONGHORN_CHART_SHA256}" "${chart_dir}")"
  "${HELM_BIN}" upgrade --install longhorn "${chart_archive}" \
    --namespace longhorn-system \
    -f "${LONGHORN_VALUES_FILE}" \
    --set defaultSettings.defaultReplicaCount="${LONGHORN_REPLICA_COUNT}" \
    --set defaultSettings.defaultDataPath="${LONGHORN_DATA_PATH}"
  rm -rf "${chart_dir}"
  trap - EXIT
  kctl -n longhorn-system rollout status deployment/longhorn-driver-deployer --timeout=10m

  if [[ "${LONGHORN_SINGLE_NODE_MODE}" == "y" ]]; then
    kctl apply -f - <<EOF
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: longhorn-single
  annotations:
    storageclass.kubernetes.io/is-default-class: "false"
provisioner: driver.longhorn.io
allowVolumeExpansion: true
reclaimPolicy: Delete
volumeBindingMode: Immediate
parameters:
  numberOfReplicas: "1"
EOF
    kctl patch settings.longhorn.io storage-minimal-available-percentage -n longhorn-system --type=merge -p "{\"value\":\"${LONGHORN_MINIMAL_AVAILABLE_PERCENTAGE}\"}" || true
  fi

  if [[ "${LONGHORN_MAKE_DEFAULT}" == "y" ]]; then
    DEFAULT_LONGHORN_SC="longhorn"
    if [[ "${LONGHORN_SINGLE_NODE_MODE}" == "y" ]] && kctl get storageclass longhorn-single >/dev/null 2>&1; then
      DEFAULT_LONGHORN_SC="longhorn-single"
    fi
    if kctl get storageclass "${DEFAULT_LONGHORN_SC}" >/dev/null 2>&1; then
      kctl patch storageclass "${DEFAULT_LONGHORN_SC}" -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"true"}}}' >/dev/null || true
      if [[ "${DEFAULT_LONGHORN_SC}" != "longhorn" ]] && kctl get storageclass longhorn >/dev/null 2>&1; then
        kctl patch storageclass longhorn -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' >/dev/null || true
      fi
      if kctl get storageclass local-path >/dev/null 2>&1; then
        kctl patch storageclass local-path -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' >/dev/null || true
      fi
      if kctl get storageclass longhorn-static >/dev/null 2>&1; then
        kctl patch storageclass longhorn-static -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' >/dev/null || true
      fi
    fi
  elif kctl get storageclass longhorn >/dev/null 2>&1; then
    kctl patch storageclass longhorn -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' >/dev/null || true
    if kctl get storageclass longhorn-single >/dev/null 2>&1; then
      kctl patch storageclass longhorn-single -p '{"metadata":{"annotations":{"storageclass.kubernetes.io/is-default-class":"false"}}}' >/dev/null || true
    fi
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  pk3s_addon_install "$@"
fi

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../scripts/addon-host-runtime.sh"

KUBECTL_BIN="${PK3S_KUBECTL_BIN:-kubectl}"
HELM_BIN="${PK3S_HELM_BIN:-helm}"
KUBECTL_MODE="${PK3S_KUBECTL_MODE:-kubectl}"
LONGHORN_VERSION="${PK3S_LONGHORN_VERSION:-v1.11.1}"
LONGHORN_DATA_PATH="${PK3S_LONGHORN_DATA_PATH:-/data}"
LONGHORN_REPLICA_COUNT="${PK3S_LONGHORN_REPLICA_COUNT:-1}"
LONGHORN_SINGLE_NODE_MODE="${PK3S_LONGHORN_SINGLE_NODE_MODE:-n}"
LONGHORN_MINIMAL_AVAILABLE_PERCENTAGE="${PK3S_LONGHORN_MINIMAL_AVAILABLE_PERCENTAGE:-10}"
LONGHORN_MAKE_DEFAULT="${PK3S_LONGHORN_MAKE_DEFAULT:-n}"

kctl() {
  if [[ "${KUBECTL_MODE}" == "k3s" ]]; then
    sudo k3s kubectl "$@"
  else
    "${KUBECTL_BIN}" "$@"
  fi
}

pk3s_addon_install() {
  pk3s_ensure_packages_optional "Longhorn" open-iscsi jq
  pk3s_enable_service_optional iscsid
  pk3s_runtime_warn "Longhorn storage path '${LONGHORN_DATA_PATH}' will be created if missing."
  pk3s_runtime_warn "This add-on will not format or mount disks. Prepare dedicated mounted storage yourself if you need it."
  pk3s_ensure_directory_optional "${LONGHORN_DATA_PATH}"

  kctl create namespace longhorn-system >/dev/null 2>&1 || true
  "${HELM_BIN}" repo add longhorn https://charts.longhorn.io >/dev/null 2>&1 || true
  "${HELM_BIN}" repo update >/dev/null
  "${HELM_BIN}" upgrade --install longhorn longhorn/longhorn \
    --namespace longhorn-system \
    --version "${LONGHORN_VERSION}" \
    --set defaultSettings.defaultReplicaCount="${LONGHORN_REPLICA_COUNT}" \
    --set defaultSettings.defaultDataPath="${LONGHORN_DATA_PATH}"
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

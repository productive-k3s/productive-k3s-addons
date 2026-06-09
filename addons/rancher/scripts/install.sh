#!/usr/bin/env bash
set -euo pipefail

ADDON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ADDON_SCRIPT_DIR}/../../../scripts/addon-host-runtime.sh"

KUBECTL_BIN="${PK3S_KUBECTL_BIN:-kubectl}"
HELM_BIN="${PK3S_HELM_BIN:-helm}"
KUBECTL_MODE="${PK3S_KUBECTL_MODE:-kubectl}"
RANCHER_VERSION="${PK3S_RANCHER_VERSION:-v2.14.2}"
RANCHER_HOST="${PK3S_RANCHER_HOST:-rancher.k3s.lab.internal}"
BOOTSTRAP_PASSWORD="${PK3S_RANCHER_BOOTSTRAP_PASSWORD:-admin}"
TLS_SOURCE="${PK3S_TLS_SOURCE:-secret}"
CLUSTER_ISSUER="${PK3S_CLUSTER_ISSUER:-selfsigned-issuer}"
LE_EMAIL="${PK3S_LETSENCRYPT_EMAIL:-admin@example.invalid}"
LE_ENVIRONMENT="${PK3S_LETSENCRYPT_ENVIRONMENT:-staging}"
PRIVATE_CA="${PK3S_RANCHER_PRIVATE_CA:-true}"
NODE_PRIMARY_IP="${PK3S_NODE_PRIMARY_IP:-}"
MANAGE_LOCAL_HOSTS="${PK3S_RANCHER_MANAGE_LOCAL_HOSTS:-n}"

kctl() {
  if [[ "${KUBECTL_MODE}" == "k3s" ]]; then
    sudo k3s kubectl "$@"
  else
    "${KUBECTL_BIN}" "$@"
  fi
}

wait_secret() {
  local namespace="$1"
  local secret="$2"
  local deadline=$((SECONDS + 120))
  while (( SECONDS < deadline )); do
    if kctl -n "${namespace}" get secret "${secret}" >/dev/null 2>&1; then
      return 0
    fi
    sleep 5
  done
  printf 'timed out waiting for secret: %s/%s\n' "${namespace}" "${secret}" >&2
  return 1
}

wait_certificate_ready() {
  local namespace="$1"
  local certificate="$2"
  local deadline=$((SECONDS + 180))
  while (( SECONDS < deadline )); do
    if kctl -n "${namespace}" get certificate "${certificate}" -o jsonpath='{.status.conditions[?(@.type=="Ready")].status}' 2>/dev/null | grep -qx 'True'; then
      return 0
    fi
    sleep 5
  done
  printf 'timed out waiting for certificate readiness: %s/%s\n' "${namespace}" "${certificate}" >&2
  return 1
}

ensure_rancher_private_ca_secret() {
  if kctl -n cattle-system get secret tls-ca >/dev/null 2>&1; then
    return 0
  fi
  local source_secret_name="rancher-tls"
  kctl -n cattle-system get secret "${source_secret_name}" -o jsonpath='{.data.tls\.crt}' 2>/dev/null | base64 -d > /tmp/rancher-ca.crt
  kctl -n cattle-system create secret generic tls-ca --from-file=cacerts.pem=/tmp/rancher-ca.crt >/dev/null
  rm -f /tmp/rancher-ca.crt
}

pk3s_addon_install() {
  kctl create namespace cattle-system >/dev/null 2>&1 || true
  "${HELM_BIN}" repo add rancher-latest https://releases.rancher.com/server-charts/latest >/dev/null 2>&1 || true
  "${HELM_BIN}" repo update >/dev/null

  if [[ "${TLS_SOURCE}" == "secret" ]]; then
    kctl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: rancher-tls
  namespace: cattle-system
spec:
  secretName: rancher-tls
  issuerRef:
    name: ${CLUSTER_ISSUER}
    kind: ClusterIssuer
  dnsNames:
    - ${RANCHER_HOST}
EOF
    wait_secret cattle-system rancher-tls
    wait_certificate_ready cattle-system rancher-tls
    ensure_rancher_private_ca_secret
    "${HELM_BIN}" upgrade --install rancher rancher-latest/rancher \
      --namespace cattle-system \
      --version "${RANCHER_VERSION}" \
      --set hostname="${RANCHER_HOST}" \
      --set bootstrapPassword="${BOOTSTRAP_PASSWORD}" \
      --set ingress.tls.source=secret \
      --set privateCA="${PRIVATE_CA}"
  else
    "${HELM_BIN}" upgrade --install rancher rancher-latest/rancher \
      --namespace cattle-system \
      --version "${RANCHER_VERSION}" \
      --set hostname="${RANCHER_HOST}" \
      --set bootstrapPassword="${BOOTSTRAP_PASSWORD}" \
      --set ingress.tls.source=letsEncrypt \
      --set letsEncrypt.email="${LE_EMAIL}" \
      --set letsEncrypt.environment="${LE_ENVIRONMENT}"
  fi

  kctl -n cattle-system rollout status deployment/rancher --timeout=10m || true

  if [[ "${MANAGE_LOCAL_HOSTS}" == "y" && -n "${NODE_PRIMARY_IP}" ]]; then
    pk3s_replace_local_hosts_entry "${RANCHER_HOST}" "${NODE_PRIMARY_IP}" "rancher_host_local"
  else
    pk3s_manifest_complete_optional "rancher_host_local" "skipped"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  pk3s_addon_install "$@"
fi

#!/usr/bin/env bash
set -euo pipefail

KUBECTL_BIN="${PK3S_KUBECTL_BIN:-kubectl}"
CERT_MANAGER_VERSION="${PK3S_CERT_MANAGER_VERSION:-v1.19.4}"
KUBECTL_MODE="${PK3S_KUBECTL_MODE:-kubectl}"
CLUSTER_ISSUER_ACTION="${PK3S_CLUSTER_ISSUER_ACTION:-skip}"
TLS_SOURCE="${PK3S_TLS_SOURCE:-secret}"
CLUSTER_ISSUER="${PK3S_CLUSTER_ISSUER:-selfsigned}"
LE_EMAIL="${PK3S_LETSENCRYPT_EMAIL:-admin@example.invalid}"
LE_ENVIRONMENT="${PK3S_LETSENCRYPT_ENVIRONMENT:-staging}"
INGRESS_CLASS_NAME="${PK3S_INGRESS_CLASS_NAME:-traefik}"

wait_rollout() {
  local namespace="$1"
  local deployment="$2"
  kctl -n "${namespace}" rollout status "deployment/${deployment}" --timeout=10m
}

wait_endpoints() {
  local namespace="$1"
  local service="$2"
  local deadline=$((SECONDS + 180))
  while (( SECONDS < deadline )); do
    if kctl -n "${namespace}" get endpoints "${service}" -o jsonpath='{.subsets[0].addresses[0].ip}' 2>/dev/null | grep -q .; then
      return 0
    fi
    sleep 5
  done
  printf 'timed out waiting for service endpoints: %s/%s\n' "${namespace}" "${service}" >&2
  return 1
}

kctl() {
  if [[ "${KUBECTL_MODE}" == "k3s" ]]; then
    sudo k3s kubectl "$@"
  else
    "${KUBECTL_BIN}" "$@"
  fi
}

clusterissuer_exists() {
  kctl get clusterissuer "$1" >/dev/null 2>&1
}

pk3s_addon_install() {
  kctl create namespace cert-manager >/dev/null 2>&1 || true
  kctl apply -f "https://github.com/cert-manager/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml"
  wait_rollout cert-manager cert-manager
  wait_rollout cert-manager cert-manager-webhook
  wait_rollout cert-manager cert-manager-cainjector
  wait_endpoints cert-manager cert-manager-webhook

  if [[ "${CLUSTER_ISSUER_ACTION}" == "install" ]] && ! clusterissuer_exists "${CLUSTER_ISSUER}"; then
    printf '[INFO] Creating ClusterIssuer %s via cert-manager addon\n' "${CLUSTER_ISSUER}"
    if [[ "${TLS_SOURCE}" == "letsencrypt" ]]; then
      cat <<EOF | kctl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${CLUSTER_ISSUER}
spec:
  acme:
    email: ${LE_EMAIL}
    server: $( [[ "${LE_ENVIRONMENT}" == "production" ]] && echo "https://acme-v02.api.letsencrypt.org/directory" || echo "https://acme-staging-v02.api.letsencrypt.org/directory" )
    privateKeySecretRef:
      name: ${CLUSTER_ISSUER}-account-key
    solvers:
    - http01:
        ingress:
          ingressClassName: ${INGRESS_CLASS_NAME}
EOF
    else
      cat <<EOF | kctl apply -f -
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ${CLUSTER_ISSUER}
spec:
  selfSigned: {}
EOF
    fi
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  pk3s_addon_install "$@"
fi

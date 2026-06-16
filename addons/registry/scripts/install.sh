#!/usr/bin/env bash
set -euo pipefail

ADDON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ADDON_SCRIPT_DIR}/../../../scripts/addon-host-runtime.sh"

KUBECTL_BIN="${PK3S_KUBECTL_BIN:-kubectl}"
KUBECTL_MODE="${PK3S_KUBECTL_MODE:-kubectl}"
REGISTRY_IMAGE="${PK3S_REGISTRY_IMAGE:-registry:2.8.3}"
REGISTRY_HOST="${PK3S_REGISTRY_HOST:-registry.k3s.lab.internal}"
REGISTRY_SIZE="${PK3S_REGISTRY_PVC_SIZE:-20Gi}"
REGISTRY_STORAGE_CLASS="${PK3S_REGISTRY_STORAGE_CLASS:-}"
TLS_SOURCE="${PK3S_TLS_SOURCE:-secret}"
CLUSTER_ISSUER="${PK3S_CLUSTER_ISSUER:-selfsigned-issuer}"
REGISTRY_AUTH_ENABLED="${PK3S_REGISTRY_AUTH_ENABLED:-n}"
REGISTRY_AUTH_USER="${PK3S_REGISTRY_AUTH_USER:-registry}"
REGISTRY_AUTH_PASSWORD="${PK3S_REGISTRY_AUTH_PASSWORD:-change-me}"
NODE_PRIMARY_IP="${PK3S_NODE_PRIMARY_IP:-}"
MANAGE_LOCAL_HOSTS="${PK3S_REGISTRY_MANAGE_LOCAL_HOSTS:-n}"
TRUST_LOCAL_DOCKER="${PK3S_REGISTRY_TRUST_DOCKER:-n}"
INGRESS_CLASS_NAME="${PK3S_INGRESS_CLASS_NAME:-traefik}"

kctl() {
  pk3s_addon_kubectl "$@"
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

pk3s_addon_install() {
  kctl create namespace registry >/dev/null 2>&1 || true

  if [[ "${TLS_SOURCE}" == "secret" ]]; then
    kctl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: registry-tls
  namespace: registry
spec:
  secretName: registry-tls
  issuerRef:
    name: ${CLUSTER_ISSUER}
    kind: ClusterIssuer
  dnsNames:
    - ${REGISTRY_HOST}
EOF
    wait_secret registry registry-tls
    wait_certificate_ready registry registry-tls
  fi

  if [[ "${REGISTRY_AUTH_ENABLED}" == "y" ]]; then
    command -v openssl >/dev/null 2>&1 || {
      printf 'openssl is required to generate registry auth entries\n' >&2
      exit 1
    }
    AUTH_HASH="$(openssl passwd -apr1 "${REGISTRY_AUTH_PASSWORD}")"
    kctl delete secret registry-auth -n registry >/dev/null 2>&1 || true
    printf '%s:%s\n' "${REGISTRY_AUTH_USER}" "${AUTH_HASH}" | kctl create secret generic registry-auth -n registry --from-file=htpasswd=/dev/stdin >/dev/null
  fi

  PVC_STORAGE_CLASS_BLOCK=""
  if [[ -n "${REGISTRY_STORAGE_CLASS}" ]]; then
    PVC_STORAGE_CLASS_BLOCK="  storageClassName: ${REGISTRY_STORAGE_CLASS}"
  fi

  INGRESS_ANNOTATIONS=""
  if [[ "${TLS_SOURCE}" == "letsencrypt" ]]; then
    INGRESS_ANNOTATIONS="  annotations:\n    cert-manager.io/cluster-issuer: ${CLUSTER_ISSUER}"
  fi

  REGISTRY_AUTH_ENV_BLOCK=""
  REGISTRY_AUTH_MOUNT_BLOCK=""
  REGISTRY_AUTH_VOLUME_BLOCK=""
  if [[ "${REGISTRY_AUTH_ENABLED}" == "y" ]]; then
    REGISTRY_AUTH_ENV_BLOCK="        - name: REGISTRY_AUTH\n          value: htpasswd\n        - name: REGISTRY_AUTH_HTPASSWD_REALM\n          value: Registry Realm\n        - name: REGISTRY_AUTH_HTPASSWD_PATH\n          value: /auth/htpasswd"
    REGISTRY_AUTH_MOUNT_BLOCK="        - name: auth\n          mountPath: /auth\n          readOnly: true"
    REGISTRY_AUTH_VOLUME_BLOCK="      - name: auth\n        secret:\n          secretName: registry-auth"
  fi

  cat <<EOF | kctl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: registry
  namespace: registry
spec:
  replicas: 1
  selector:
    matchLabels:
      app: registry
  template:
    metadata:
      labels:
        app: registry
    spec:
      containers:
      - name: registry
        image: ${REGISTRY_IMAGE}
        imagePullPolicy: IfNotPresent
        ports:
        - containerPort: 5000
          name: http
        env:
        - name: REGISTRY_HTTP_ADDR
          value: 0.0.0.0:5000
$(printf '%b\n' "${REGISTRY_AUTH_ENV_BLOCK}")
        volumeMounts:
        - name: data
          mountPath: /var/lib/registry
$(printf '%b\n' "${REGISTRY_AUTH_MOUNT_BLOCK}")
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: registry-data
$(printf '%b\n' "${REGISTRY_AUTH_VOLUME_BLOCK}")
---
apiVersion: v1
kind: Service
metadata:
  name: registry
  namespace: registry
spec:
  selector:
    app: registry
  ports:
  - name: http
    port: 5000
    targetPort: http
---
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: registry-data
  namespace: registry
spec:
  accessModes:
  - ReadWriteOnce
${PVC_STORAGE_CLASS_BLOCK}
  resources:
    requests:
      storage: ${REGISTRY_SIZE}
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: registry
  namespace: registry
$(printf '%b\n' "${INGRESS_ANNOTATIONS}")
spec:
  ingressClassName: ${INGRESS_CLASS_NAME}
  tls:
  - hosts:
    - ${REGISTRY_HOST}
    secretName: registry-tls
  rules:
  - host: ${REGISTRY_HOST}
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
              service:
                name: registry
                port:
                  number: 5000
EOF
  kctl -n registry rollout status deployment/registry --timeout=10m

  if [[ "${MANAGE_LOCAL_HOSTS}" == "y" && -n "${NODE_PRIMARY_IP}" ]]; then
    pk3s_replace_local_hosts_entry "${REGISTRY_HOST}" "${NODE_PRIMARY_IP}" "registry_host_local"
  else
    pk3s_manifest_complete_optional "registry_host_local" "skipped"
  fi

  if [[ "${TLS_SOURCE}" == "secret" && "${TRUST_LOCAL_DOCKER}" == "y" ]]; then
    pk3s_install_local_docker_trust "registry" "registry-tls" "${REGISTRY_HOST}" "registry_docker_trust"
  else
    pk3s_manifest_complete_optional "registry_docker_trust" "skipped"
  fi
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  pk3s_addon_install "$@"
fi

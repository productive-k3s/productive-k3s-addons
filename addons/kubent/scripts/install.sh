#!/usr/bin/env bash
set -euo pipefail

ADDON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ADDON_SCRIPT_DIR}/../../../scripts/addon-host-runtime.sh"

KUBECTL_BIN="${PK3S_KUBECTL_BIN:-kubectl}"
KUBENT_NAMESPACE="${PK3S_KUBENT_NAMESPACE:-pk3s-kubent}"
KUBENT_JOB_NAME="${PK3S_KUBENT_JOB_NAME:-pk3s-kubent-scan}"
KUBENT_IMAGE="${PK3S_KUBENT_IMAGE:-ghcr.io/doitintl/kube-no-trouble:0.7.3}"
KUBENT_ARGS="${PK3S_KUBENT_ARGS:-"--output text"}"

kctl() {
  if declare -F pk3s_addon_kubectl >/dev/null 2>&1; then
    pk3s_addon_kubectl "$@"
  else
    "${KUBECTL_BIN}" "$@"
  fi
}

pk3s_addon_install() {
  local rendered_args
  rendered_args="$(printf '%s\n' "${KUBENT_ARGS}" | awk '{
    for (i = 1; i <= NF; i++) {
      gsub(/"/, "\\\"", $i)
      printf "            - \"%s\"\n", $i
    }
  }')"

  kctl create namespace "${KUBENT_NAMESPACE}" >/dev/null 2>&1 || true
  kctl delete job "${KUBENT_JOB_NAME}" -n "${KUBENT_NAMESPACE}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kctl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: kubent
  namespace: ${KUBENT_NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pk3s-kubent-readonly
  labels:
    app.kubernetes.io/name: kubent
    app.kubernetes.io/part-of: productive-k3s
rules:
  - apiGroups:
      - "*"
    resources:
      - "*"
    verbs:
      - get
      - list
      - watch
  - nonResourceURLs:
      - /version
    verbs:
      - get
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: pk3s-kubent-readonly
  labels:
    app.kubernetes.io/name: kubent
    app.kubernetes.io/part-of: productive-k3s
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: pk3s-kubent-readonly
subjects:
  - kind: ServiceAccount
    name: kubent
    namespace: ${KUBENT_NAMESPACE}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: ${KUBENT_JOB_NAME}
  namespace: ${KUBENT_NAMESPACE}
  labels:
    app.kubernetes.io/name: kubent
    app.kubernetes.io/part-of: productive-k3s
spec:
  backoffLimit: 0
  ttlSecondsAfterFinished: 86400
  template:
    metadata:
      labels:
        app.kubernetes.io/name: kubent
        app.kubernetes.io/part-of: productive-k3s
    spec:
      serviceAccountName: kubent
      restartPolicy: Never
      containers:
        - name: kubent
          image: ${KUBENT_IMAGE}
          imagePullPolicy: IfNotPresent
          args:
${rendered_args}
EOF
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  pk3s_addon_install "$@"
fi

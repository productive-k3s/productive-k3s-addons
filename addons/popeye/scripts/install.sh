#!/usr/bin/env bash
set -euo pipefail

ADDON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ADDON_SCRIPT_DIR}/../../../scripts/addon-host-runtime.sh"

KUBECTL_BIN="${PK3S_KUBECTL_BIN:-kubectl}"
POPEYE_NAMESPACE="${PK3S_POPEYE_NAMESPACE:-pk3s-popeye}"
POPEYE_JOB_NAME="${PK3S_POPEYE_JOB_NAME:-pk3s-popeye-scan}"
POPEYE_IMAGE="${PK3S_POPEYE_IMAGE:-quay.io/derailed/popeye:v0.22.1}"
POPEYE_ARGS="${PK3S_POPEYE_ARGS:--A -o jurassic --logs none}"
POPEYE_ALLOW_FINDINGS="${PK3S_POPEYE_ALLOW_FINDINGS:-true}"

kctl() {
  if declare -F pk3s_addon_kubectl >/dev/null 2>&1; then
    pk3s_addon_kubectl "$@"
  else
    "${KUBECTL_BIN}" "$@"
  fi
}

pk3s_addon_install() {
  local rendered_args
  rendered_args="$(printf '%s\n' "${POPEYE_ARGS}" | awk '{
    for (i = 1; i <= NF; i++) {
      gsub(/"/, "\\\"", $i)
      printf "            - \"%s\"\n", $i
    }
  }')"
  local command_block
  if [[ "${POPEYE_ALLOW_FINDINGS}" == "true" ]]; then
    command_block='          command:
            - sh
            - -c
          args:
            - |
              popeye "$@"
              rc=$?
              printf "popeye_exit_code=%s\n" "$rc"
              exit 0
            - popeye'
  else
    command_block='          args:'
  fi

  kctl create namespace "${POPEYE_NAMESPACE}" >/dev/null 2>&1 || true
  kctl delete job "${POPEYE_JOB_NAME}" -n "${POPEYE_NAMESPACE}" --ignore-not-found --wait=false >/dev/null 2>&1 || true
  kctl apply -f - <<EOF
apiVersion: v1
kind: ServiceAccount
metadata:
  name: popeye
  namespace: ${POPEYE_NAMESPACE}
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: pk3s-popeye-readonly
  labels:
    app.kubernetes.io/name: popeye
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
      - /healthz
      - /metrics
      - /version
    verbs:
      - get
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: pk3s-popeye-readonly
  labels:
    app.kubernetes.io/name: popeye
    app.kubernetes.io/part-of: productive-k3s
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: pk3s-popeye-readonly
subjects:
  - kind: ServiceAccount
    name: popeye
    namespace: ${POPEYE_NAMESPACE}
---
apiVersion: batch/v1
kind: Job
metadata:
  name: ${POPEYE_JOB_NAME}
  namespace: ${POPEYE_NAMESPACE}
  labels:
    app.kubernetes.io/name: popeye
    app.kubernetes.io/part-of: productive-k3s
spec:
  backoffLimit: 0
  ttlSecondsAfterFinished: 86400
  template:
    metadata:
      labels:
        app.kubernetes.io/name: popeye
        app.kubernetes.io/part-of: productive-k3s
    spec:
      serviceAccountName: popeye
      restartPolicy: Never
      containers:
        - name: popeye
          image: ${POPEYE_IMAGE}
          imagePullPolicy: IfNotPresent
          env:
            - name: TERM
              value: xterm-256color
${command_block}
${rendered_args}
EOF
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  pk3s_addon_install "$@"
fi

#!/usr/bin/env bash
set -euo pipefail

ADDON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ADDON_SCRIPT_DIR}/../../../scripts/addon-host-runtime.sh"

KUBECTL_BIN="${PK3S_KUBECTL_BIN:-kubectl}"
HELM_BIN="${PK3S_HELM_BIN:-helm}"
KYVERNO_NAMESPACE="${PK3S_KYVERNO_NAMESPACE:-kyverno}"
KYVERNO_CHART_VERSION="${PK3S_KYVERNO_CHART_VERSION:-3.9.0}"
KYVERNO_VALIDATION_FAILURE_ACTION="${PK3S_KYVERNO_VALIDATION_FAILURE_ACTION:-Audit}"

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
  kctl create namespace "${KYVERNO_NAMESPACE}" >/dev/null 2>&1 || true
  "${HELM_BIN}" repo add kyverno https://kyverno.github.io/kyverno/ >/dev/null 2>&1 || true
  "${HELM_BIN}" repo update >/dev/null
  "${HELM_BIN}" upgrade --install kyverno kyverno/kyverno \
    --namespace "${KYVERNO_NAMESPACE}" \
    --version "${KYVERNO_CHART_VERSION}"
  kctl -n "${KYVERNO_NAMESPACE}" rollout status deployment/kyverno-admission-controller --timeout=10m

  # Productive K3S starts Kyverno with audit-only policies so existing workloads are never blocked by default.
  kctl apply -f - <<EOF
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: pk3s-audit-disallow-latest-image-tag
  labels:
    app.kubernetes.io/part-of: productive-k3s
spec:
  validationFailureAction: ${KYVERNO_VALIDATION_FAILURE_ACTION}
  background: true
  rules:
    - name: require-non-latest-image-tag
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Avoid the mutable latest image tag."
        pattern:
          spec:
            containers:
              - image: "!*:latest"
---
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: pk3s-audit-require-workload-labels
  labels:
    app.kubernetes.io/part-of: productive-k3s
spec:
  validationFailureAction: ${KYVERNO_VALIDATION_FAILURE_ACTION}
  background: true
  rules:
    - name: require-app-name-label
      match:
        any:
          - resources:
              kinds:
                - Pod
      validate:
        message: "Pods should carry app.kubernetes.io/name."
        pattern:
          metadata:
            labels:
              app.kubernetes.io/name: "?*"
EOF
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  pk3s_addon_install "$@"
fi

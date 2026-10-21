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
KYVERNO_NAMESPACE="${PK3S_KYVERNO_NAMESPACE:-kyverno}"
KYVERNO_CHART_VERSION="${PK3S_KYVERNO_CHART_VERSION:-3.9.0}"
KYVERNO_CHART_SHA256="${PK3S_KYVERNO_CHART_SHA256:-9663e8d3d15b070e5925b4f26b3f9a8824872a42ac7bf27ca105c897cb5aba51}"
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
  local chart_dir chart_archive
  chart_dir="$(mktemp -d)"
  trap 'rm -rf "${chart_dir}"' RETURN
  chart_archive="$(pk3s_pull_verified_helm_chart "${HELM_BIN}" kyverno https://kyverno.github.io/kyverno kyverno "${KYVERNO_CHART_VERSION}" "${KYVERNO_CHART_SHA256}" "${chart_dir}")"

  kctl create namespace "${KYVERNO_NAMESPACE}" >/dev/null 2>&1 || true
  "${HELM_BIN}" upgrade --install kyverno "${chart_archive}" \
    --namespace "${KYVERNO_NAMESPACE}" \
    -f "${VALUES_FILE}"
  kctl -n "${KYVERNO_NAMESPACE}" rollout status deployment/kyverno-admission-controller --timeout=10m

  # Productive K3S starts Kyverno with audit-only policies so existing workloads are never blocked by default.
  kctl apply -f - <<MANIFEST
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
MANIFEST
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  pk3s_addon_install "$@"
fi

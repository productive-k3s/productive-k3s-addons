#!/usr/bin/env bash
set -euo pipefail

ADDON_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${ADDON_SCRIPT_DIR}/../../../scripts/addon-host-runtime.sh"
VERIFIED_HELM_CHART_SCRIPT="${ADDON_SCRIPT_DIR}/verified-helm-chart.sh"
[[ -f "${VERIFIED_HELM_CHART_SCRIPT}" ]] || VERIFIED_HELM_CHART_SCRIPT="${ADDON_SCRIPT_DIR}/../../../scripts/verified-helm-chart.sh"
source "${VERIFIED_HELM_CHART_SCRIPT}"

KUBECTL_BIN="${PK3S_KUBECTL_BIN:-kubectl}"
HELM_BIN="${PK3S_HELM_BIN:-helm}"
GEOSERVER_NAMESPACE="${PK3S_GEOSERVER_NAMESPACE:-geoserver}"
GEOSERVER_RELEASE_NAME="${PK3S_GEOSERVER_RELEASE_NAME:-geoserver-cloud}"
GEOSERVER_CHART_DIR="${PK3S_GEOSERVER_CHART_DIR:-${ADDON_SCRIPT_DIR}/../chart}"
GEOSERVER_CHART_SHA256="${PK3S_GEOSERVER_CHART_SHA256:-0ab9bdce03187e6010538145a56427335b00a538f16889dfd60c23f9e1822af2}"
RABBITMQ_CHART_SHA256="${PK3S_RABBITMQ_CHART_SHA256:-fa3b781ca25871ffa61da4422615e3aa14054946a8dac91c6ffd19a58de5dd6d}"
GEOSERVER_HOST="${PK3S_GEOSERVER_HOST:-geoserver.k3s.lab.internal}"
GEOSERVER_INGRESS_ENABLED="${PK3S_GEOSERVER_INGRESS_ENABLED:-n}"
GEOSERVER_TLS_ENABLED="${PK3S_GEOSERVER_TLS_ENABLED:-y}"
GEOSERVER_TLS_SECRET="${PK3S_GEOSERVER_TLS_SECRET:-geoserver-cloud-tls}"
INGRESS_CLASS_NAME="${PK3S_INGRESS_CLASS_NAME:-traefik}"

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
  kctl create namespace "${GEOSERVER_NAMESPACE}" >/dev/null 2>&1 || true

  pk3s_verify_file_sha256 "${GEOSERVER_CHART_DIR}/charts/geoservercloud-3.0.1.tgz" "${GEOSERVER_CHART_SHA256}" "GeoServer Cloud chart archive"
  pk3s_verify_file_sha256 "${GEOSERVER_CHART_DIR}/charts/rabbitmq-14.4.0.tgz" "${RABBITMQ_CHART_SHA256}" "RabbitMQ chart archive"

  local helm_args=(
    upgrade --install "${GEOSERVER_RELEASE_NAME}" "${GEOSERVER_CHART_DIR}"
    --namespace "${GEOSERVER_NAMESPACE}"
    --create-namespace
    --wait
    --timeout 20m
  )

  if [[ "${GEOSERVER_INGRESS_ENABLED}" == "y" ]]; then
    helm_args+=(
      --set geoservercloud.geoserver.ingress.enabled=true
      --set geoservercloud.geoserver.services.gateway.ingress.enabled=true
      --set "geoservercloud.geoserver.ingress.hostGroups.pk3s.hosts[0]=${GEOSERVER_HOST}"
      --set "geoservercloud.geoserver.ingress.hostGroups.pk3s.tls.enabled=${GEOSERVER_TLS_ENABLED}"
      --set "geoservercloud.geoserver.ingress.hostGroups.pk3s.tls.secretName=${GEOSERVER_TLS_SECRET}"
      --set "geoservercloud.geoserver.ingress.className=${INGRESS_CLASS_NAME}"
    )
  fi

  "${HELM_BIN}" "${helm_args[@]}"

  kctl -n "${GEOSERVER_NAMESPACE}" rollout status "deployment/${GEOSERVER_RELEASE_NAME}-gsc-gateway" --timeout=10m
  kctl -n "${GEOSERVER_NAMESPACE}" rollout status "deployment/${GEOSERVER_RELEASE_NAME}-gsc-webui" --timeout=10m
  kctl -n "${GEOSERVER_NAMESPACE}" rollout status "deployment/${GEOSERVER_RELEASE_NAME}-gsc-rest" --timeout=10m
  kctl -n "${GEOSERVER_NAMESPACE}" rollout status "deployment/${GEOSERVER_RELEASE_NAME}-gsc-wms" --timeout=10m
  kctl -n "${GEOSERVER_NAMESPACE}" rollout status "deployment/${GEOSERVER_RELEASE_NAME}-gsc-wfs" --timeout=10m
  kctl -n "${GEOSERVER_NAMESPACE}" rollout status "deployment/${GEOSERVER_RELEASE_NAME}-gsc-gwc" --timeout=10m
  kctl -n "${GEOSERVER_NAMESPACE}" rollout status "deployment/${GEOSERVER_RELEASE_NAME}-gsc-acl" --timeout=10m
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  pk3s_addon_install "$@"
fi

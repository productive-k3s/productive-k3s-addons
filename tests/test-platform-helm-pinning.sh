#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${ROOT_DIR}/scripts/verified-helm-chart.sh"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

command -v helm >/dev/null 2>&1 || fail "helm is required"
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is required"

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT
export HELM_CONFIG_HOME="${work_dir}/helm/config"
export HELM_CACHE_HOME="${work_dir}/helm/cache"
export HELM_DATA_HOME="${work_dir}/helm/data"
mkdir -p "${HELM_CONFIG_HOME}" "${HELM_CACHE_HOME}" "${HELM_DATA_HOME}"

rendered_images() {
  sed -nE 's/^[[:space:]]*(-[[:space:]]+)?image:[[:space:]]+"?([^[:space:]"{]+)"?[[:space:]]*$/\2/p' "$1" | sort -u
}

assert_rendered_images_are_locked() {
  local addon="$1"
  local rendered="$2"
  local lock_file="${ROOT_DIR}/addons/${addon}/materials.lock.yaml"
  local image digest

  while IFS= read -r image; do
    [[ -n "${image}" ]] || continue
    [[ "${image}" == *@sha256:* ]] || fail "${addon} rendered an image without digest: ${image}"
    digest="sha256:${image##*@sha256:}"
    grep -Fq "digest: \"${digest}\"" "${lock_file}" || fail "${addon} rendered digest missing from MaterialsLock: ${digest}"
  done < <(rendered_images "${rendered}")
}

assert_values_digests_are_locked_and_rendered() {
  local addon="$1"
  local values_file="$2"
  local rendered="$3"
  local lock_file="${ROOT_DIR}/addons/${addon}/materials.lock.yaml"
  local digest

  while IFS= read -r digest; do
    grep -Fq "${digest}" "${lock_file}" || fail "${addon} values digest missing from MaterialsLock: ${digest}"
    grep -Fq "${digest}" "${rendered}" || fail "${addon} values digest missing from rendered output: ${digest}"
  done < <(grep -oE 'sha256:[0-9a-f]{64}' "${values_file}" | sort -u)
}

pull_and_render() {
  local addon="$1"
  local alias="$2"
  local repository="$3"
  local chart="$4"
  local version="$5"
  local chart_sha="$6"
  local expected_materials="$7"
  shift 7
  local chart_dir="${work_dir}/charts/${addon}"
  local archive rendered lock_file install_script values_file

  lock_file="${ROOT_DIR}/addons/${addon}/materials.lock.yaml"
  install_script="${ROOT_DIR}/addons/${addon}/scripts/install.sh"
  values_file="${ROOT_DIR}/addons/${addon}/values.yaml"
  mkdir -p "${chart_dir}"

  grep -Fq "digest: \"sha256:${chart_sha}\"" "${lock_file}" || fail "${addon} chart digest missing from MaterialsLock"
  grep -Fq "${chart_sha}" "${install_script}" || fail "${addon} installer chart digest differs from MaterialsLock"
  grep -Fq 'verified-helm-chart.sh' "${install_script}" || fail "${addon} installer does not use the verified chart helper"
  grep -Fq 'VALUES_FILE' "${install_script}" || fail "${addon} installer does not use package-owned values"

  archive="$(pk3s_pull_verified_helm_chart helm "${alias}" "${repository}" "${chart}" "${version}" "${chart_sha}" "${chart_dir}")"
  rendered="${work_dir}/${addon}.yaml"
  helm template "${addon}" "${archive}" --namespace "${addon}" -f "${values_file}" "$@" >"${rendered}"

  assert_rendered_images_are_locked "${addon}" "${rendered}"
  assert_values_digests_are_locked_and_rendered "${addon}" "${values_file}" "${rendered}"
  [[ "$(grep -Ec 'pinPolicy:[[:space:]]*exact-digest' "${lock_file}")" -eq "${expected_materials}" ]] || fail "${addon} MaterialsLock is incomplete"
}

pull_and_render longhorn platform-longhorn https://charts.longhorn.io longhorn v1.11.1 a93f60052e5e6e308d07e93fb3ecc0e4d336bbd323b725f0689df2e4d695245b 14
pull_and_render rancher platform-rancher https://releases.rancher.com/server-charts/stable rancher v2.14.2 3ff319362e174636bf8b719dcc2541cb1988cf49109ea50cc7207e18de2b3b4a 4 --set hostname=rancher.example.invalid --set auditLog.enabled=true

geoserver_lock="${ROOT_DIR}/addons/geoserver-cloud/materials.lock.yaml"
geoserver_chart="${ROOT_DIR}/addons/geoserver-cloud/chart"
geoserver_values="${geoserver_chart}/values.yaml"
geoserver_install="${ROOT_DIR}/addons/geoserver-cloud/scripts/install.sh"
geoserver_render="${work_dir}/geoserver-cloud.yaml"

pk3s_verify_file_sha256 "${geoserver_chart}/charts/geoservercloud-3.0.1.tgz" 0ab9bdce03187e6010538145a56427335b00a538f16889dfd60c23f9e1822af2 "GeoServer Cloud chart archive"
pk3s_verify_file_sha256 "${geoserver_chart}/charts/rabbitmq-14.4.0.tgz" fa3b781ca25871ffa61da4422615e3aa14054946a8dac91c6ffd19a58de5dd6d "RabbitMQ chart archive"
grep -Fq 'name: geoservercloud' "${geoserver_lock}" || fail "GeoServer chart name is not canonical"
grep -Fq 'digest: "sha256:74a880e9392b4b7eaac227bf7db2e55778fbbef1fb87aeb42e66f9107635e00b"' "${geoserver_lock}" || fail "RabbitMQ OCI manifest digest is missing"
grep -Fq 'archiveDigest: "sha256:fa3b781ca25871ffa61da4422615e3aa14054946a8dac91c6ffd19a58de5dd6d"' "${geoserver_lock}" || fail "RabbitMQ vendored archive digest is missing"
if grep -Fq -- '--dependency-update' "${geoserver_install}"; then
  fail "GeoServer installer may not update vendored dependencies"
fi
if grep -Fq 'repo add' "${geoserver_install}"; then
  fail "GeoServer installer may not resolve remote chart dependencies"
fi

helm template geoserver-cloud "${geoserver_chart}" --namespace geoserver \
  --set geoservercloud.geoserver.services.wcs.enabled=true \
  --set geoservercloud.geoserver.services.wps.enabled=true \
  --set rabbitmq.persistence.enabled=true \
  --set rabbitmq.volumePermissions.enabled=true >"${geoserver_render}"
assert_rendered_images_are_locked geoserver-cloud "${geoserver_render}"
assert_values_digests_are_locked_and_rendered geoserver-cloud "${geoserver_values}" "${geoserver_render}"
[[ "$(grep -Ec 'pinPolicy:[[:space:]]*exact-digest' "${geoserver_lock}")" -eq 14 ]] || fail "GeoServer Cloud MaterialsLock is incomplete"

printf '[PASS] platform Helm charts, vendored dependencies, and transitive images are pinned by digest\n'

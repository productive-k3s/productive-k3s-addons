#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALUES_FILE="${ROOT_DIR}/addons/nginx/values.yaml"
LOCK_FILE="${ROOT_DIR}/addons/nginx/materials.lock.yaml"
CHART_VERSION="25.2.1"

fail() {
  printf '[FAIL] %s\n' "$*" >&2
  exit 1
}

command -v helm >/dev/null 2>&1 || fail "helm is required"
command -v sha256sum >/dev/null 2>&1 || fail "sha256sum is required"

if grep -Eiq 'tag:[[:space:]]*latest([[:space:]]*)$' "${VALUES_FILE}"; then
  fail "nginx values contain a floating latest image tag"
fi

expected_chart_sha256="$(grep 'id: nginx-chart' "${LOCK_FILE}" | grep -oE 'sha256:[0-9a-f]{64}' | head -1 | cut -d: -f2)"
[[ -n "${expected_chart_sha256}" ]] || fail "nginx chart digest is missing from MaterialsLock"

chart_dir="$(mktemp -d)"
rendered="$(mktemp)"
trap 'rm -rf "${chart_dir}"; rm -f "${rendered}"' EXIT
helm pull bitnami/nginx --version "${CHART_VERSION}" --destination "${chart_dir}"
actual_chart_sha256="$(sha256sum "${chart_dir}/nginx-${CHART_VERSION}.tgz" | awk '{print $1}')"
[[ "${actual_chart_sha256}" == "${expected_chart_sha256}" ]] || fail "nginx chart digest does not match MaterialsLock"
install_script="${ROOT_DIR}/addons/nginx/scripts/install.sh"
grep -Fq "${expected_chart_sha256}" "${install_script}" || fail "nginx installer digest does not match MaterialsLock"

while IFS='|' read -r material digest; do
  grep -Fq "digest: ${digest}" "${VALUES_FILE}" || fail "nginx values are missing ${material} digest"
  grep -Fq "digest: \"${digest}\"" "${LOCK_FILE}" || fail "nginx MaterialsLock is missing ${material} digest"
done <<'DIGESTS'
nginx-image|sha256:fb69e7a082a5e90c42650ee5bfedec42628f0dd1fd89a354906eac2fb86e409b
git-image|sha256:381747741f3aba9e1818d6e1f16acd267391957efc7fbd0db55c59da4854885b
nginx-exporter-image|sha256:a76b53000a2098b65457851e1b1d190a8beecd0d296deabd6d5c96493babf1c0
DIGESTS

for material in nginx-chart nginx-image git-image nginx-exporter-image; do
  grep -Eq "id:[[:space:]]*${material}([,[:space:]}]|$)" "${LOCK_FILE}" || fail "nginx MaterialsLock is missing ${material}"
done

digest_count="$(grep -Ec 'pinPolicy:[[:space:]]*exact-digest' "${LOCK_FILE}")"
[[ "${digest_count}" -eq 4 ]] || fail "all nginx materials must use exact-digest pinning"

helm template pk3s-nginx bitnami/nginx --version "${CHART_VERSION}" --namespace pk3s-nginx -f "${VALUES_FILE}" >"${rendered}"
if grep -Eq 'image:[[:space:]]+[^[:space:]]+:latest([[:space:]]|$)' "${rendered}"; then
  fail "rendered nginx manifests contain a floating latest image tag"
fi
grep -Eq 'image:[[:space:]]+[^[:space:]]+@sha256:[0-9a-f]{64}([[:space:]]|$)' "${rendered}" || fail "rendered nginx workload is not pinned by digest"

printf '[PASS] nginx chart and container images are pinned by digest\n'

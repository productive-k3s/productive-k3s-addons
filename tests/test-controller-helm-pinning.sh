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

assert_rendered_images_are_locked() {
  local addon="$1"
  local rendered="$2"
  local lock_file="${ROOT_DIR}/addons/${addon}/materials.lock.yaml"
  local image digest

  if grep -Eiq 'image:[[:space:]]+"?[^[:space:]"@]+:(latest|main|master)([[:space:]"@]|$)' "${rendered}"; then
    fail "${addon} rendered a floating image"
  fi

  while IFS= read -r image; do
    [[ -n "${image}" ]] || continue
    [[ "${image}" == *@sha256:* ]] || fail "${addon} rendered an image without digest: ${image}"
    digest="sha256:${image##*@sha256:}"
    grep -Fq "digest: \"${digest}\"" "${lock_file}" || fail "${addon} rendered digest missing from MaterialsLock: ${digest}"
  done < <(
    sed -nE 's/^[[:space:]]+image:[[:space:]]+"?([^[:space:]"{]+)"?[[:space:]]*$/\1/p' "${rendered}" | sort -u
  )
}

assert_values_are_locked() {
  local addon="$1"
  local values_file="${ROOT_DIR}/addons/${addon}/values.yaml"
  local lock_file="${ROOT_DIR}/addons/${addon}/materials.lock.yaml"
  local digest

  if grep -Eiq 'tag:[[:space:]]*"?(latest|main|master)(@|"|[[:space:]]|$)' "${values_file}"; then
    fail "${addon} values contain a floating image tag"
  fi
  while IFS= read -r digest; do
    grep -Fq "digest: \"${digest}\"" "${lock_file}" || fail "${addon} values digest missing from MaterialsLock: ${digest}"
  done < <(grep -oE 'sha256:[0-9a-f]{64}' "${values_file}" | sort -u)
}

verify_addon() {
  local addon="$1"
  local alias="$2"
  local repository="$3"
  local chart="$4"
  local version="$5"
  local expected_sha256="$6"
  local expected_materials="$7"
  shift 7
  local lock_file="${ROOT_DIR}/addons/${addon}/materials.lock.yaml"
  local install_script="${ROOT_DIR}/addons/${addon}/scripts/install.sh"
  local values_file="${ROOT_DIR}/addons/${addon}/values.yaml"
  local chart_dir="${work_dir}/charts/${addon}"
  local archive rendered digest_count

  mkdir -p "${chart_dir}"
  grep -Fq "digest: \"sha256:${expected_sha256}\"" "${lock_file}" || fail "${addon} chart digest is missing from MaterialsLock"
  grep -Fq "${expected_sha256}" "${install_script}" || fail "${addon} installer chart digest differs from MaterialsLock"
  grep -Fq 'verified-helm-chart.sh' "${install_script}" || fail "${addon} installer does not use the verified chart helper"
  grep -Fq 'VALUES_FILE' "${install_script}" || fail "${addon} installer does not use package-owned values"

  archive="$(pk3s_pull_verified_helm_chart helm "${alias}" "${repository}" "${chart}" "${version}" "${expected_sha256}" "${chart_dir}")"
  rendered="${work_dir}/${addon}.yaml"
  helm template "${addon}" "${archive}" --namespace "${addon}" -f "${values_file}" "$@" >"${rendered}"

  assert_rendered_images_are_locked "${addon}" "${rendered}"
  assert_values_are_locked "${addon}"
  digest_count="$(grep -Ec 'pinPolicy:[[:space:]]*exact-digest' "${lock_file}")"
  [[ "${digest_count}" -eq "${expected_materials}" ]] || fail "${addon} expected ${expected_materials} exact-digest materials, found ${digest_count}"
}

verify_addon argocd audit-argo https://argoproj.github.io/argo-helm argo-cd 10.8.1 7f71e5af5eac0eb73bd79faf6fca60a644740ee4773d17f5225786ead265b064 10
verify_addon cloudnative-pg audit-cnpg https://cloudnative-pg.github.io/charts cloudnative-pg 0.29.0 668e065ff53508d58238788fd35b355a925060843629a951df0e6a9362e6d32f 2
verify_addon kyverno audit-kyverno https://kyverno.github.io/kyverno kyverno 3.9.0 9663e8d3d15b070e5925b4f26b3f9a8824872a42ac7bf27ca105c897cb5aba51 13
verify_addon trivy-operator audit-trivy https://aquasecurity.github.io/helm-charts trivy-operator 0.35.0 c9bbd17603e808f7d9eac3d02a826a717164888bd4a045a4178efcfc2ee22a6b 5 --set operator.builtInTrivyServer=false

# Exercise Argo CD's supported optional Redis exporter and Redis HA image paths.
argo_archive="${work_dir}/charts/argocd/argo-cd-10.8.1.tgz"
helm template argocd-exporter "${argo_archive}" --namespace argocd -f "${ROOT_DIR}/addons/argocd/values.yaml" --set redis.exporter.enabled=true >"${work_dir}/argocd-exporter.yaml"
assert_rendered_images_are_locked argocd "${work_dir}/argocd-exporter.yaml"
helm template argocd-ha "${argo_archive}" --namespace argocd -f "${ROOT_DIR}/addons/argocd/values.yaml" --set redis.enabled=false --set redis-ha.enabled=true --set redis-ha.exporter.enabled=true --set redis-ha.sysctlImage.enabled=true --set-json 'redis-ha.sysctlImage.command=["sysctl","-w","net.core.somaxconn=511"]' >"${work_dir}/argocd-ha.yaml"
assert_rendered_images_are_locked argocd "${work_dir}/argocd-ha.yaml"

# Exercise Kyverno's optional reports-server and its PostgreSQL helper images.
kyverno_archive="${work_dir}/charts/kyverno/kyverno-3.9.0.tgz"
helm template kyverno-reports "${kyverno_archive}" --namespace kyverno -f "${ROOT_DIR}/addons/kyverno/values.yaml" --set reportsServer.enabled=true --set reports-server.postgresql.metrics.enabled=true --set reports-server.postgresql.volumePermissions.enabled=true >"${work_dir}/kyverno-reports.yaml"
assert_rendered_images_are_locked kyverno "${work_dir}/kyverno-reports.yaml"

# Trivy stores scanner, collector, and policy OCI references in its operator ConfigMap.
for digest in \
  sha256:7cced7cae583819fc7806d4cbc0dbbc7cad18b99f7d3e235192e6da8c091045c \
  sha256:f4702ce4667388f0219d6248d623a7e816231c2d4561d6af01c3ae053e524025 \
  sha256:0491169789b867ae5a7353381220c1d4d97b3a0d6d9dfd84a25d06f0ba68aa93; do
  grep -Fq "${digest}" "${work_dir}/trivy-operator.yaml" || fail "Trivy rendered configuration is missing ${digest}"
done

printf '[PASS] controller Helm charts and transitive images are pinned by digest\n'

#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

artifact="${WORK_DIR}/base.tgz"
extract_dir="${WORK_DIR}/extract"
repository_output="${WORK_DIR}/repository"
mkdir -p "${extract_dir}"

bash "${REPO_DIR}/scripts/package-stack.sh" --stack base --output "${artifact}"
tar -xzf "${artifact}" -C "${extract_dir}"

grep -F 'name: base' "${extract_dir}/stack.yaml" >/dev/null
grep -F 'mode: bundled' "${extract_dir}/stack.yaml" >/dev/null
grep -F 'distros:' "${extract_dir}/stack.yaml" >/dev/null

for addon in cert-manager longhorn rancher registry; do
  addon_version="$(awk '/^metadata:/ { in_metadata=1; next } in_metadata && /^  version:/ { print $2; exit }' "${REPO_DIR}/addons/${addon}/addon.yaml")"
  addon_artifact="${extract_dir}/addons/${addon}-${addon_version}.tgz"
  grep -F "source: addons/${addon}-${addon_version}.tgz" "${extract_dir}/stack.yaml" >/dev/null
  [[ -s "${addon_artifact}" ]] || {
    printf '[FAIL] missing packaged add-on: %s\n' "${addon}" >&2
    exit 1
  }
  tar -tzf "${addon_artifact}" './addon.yaml' >/dev/null
done

bash "${REPO_DIR}/scripts/package-repository.sh" --output-dir "${repository_output}" >/dev/null
expected_artifacts="$(find "${REPO_DIR}/addons" "${REPO_DIR}/stacks" -mindepth 2 -maxdepth 2 -type f \( -name addon.yaml -o -name stack.yaml \) | wc -l)"
adapter_artifacts="$(find "${REPO_DIR}/adapters" -mindepth 3 -maxdepth 3 -type f -name stack.yaml | wc -l)"
expected_artifacts="$((expected_artifacts + adapter_artifacts))"
actual_artifacts="$(find "${repository_output}" -maxdepth 1 -type f -name '*.tgz' | wc -l)"
[[ "${actual_artifacts}" == "${expected_artifacts}" ]] || {
  printf '[FAIL] repository packaging produced %s artifacts; expected %s\n' "${actual_artifacts}" "${expected_artifacts}" >&2
  exit 1
}
base_version="$(awk '/^metadata:/ { in_metadata=1; next } in_metadata && /^  version:/ { print $2; exit }' "${REPO_DIR}/stacks/base/stack.yaml")"
nginx_version="$(awk '/^metadata:/ { in_metadata=1; next } in_metadata && /^  version:/ { print $2; exit }' "${REPO_DIR}/addons/nginx/addon.yaml")"
[[ -f "${repository_output}/base-${base_version}.tgz" ]]
[[ -f "${repository_output}/nginx-${nginx_version}.tgz" ]]

while IFS= read -r adapter_manifest; do
  adapter_stack="$(awk '/^metadata:/ { in_metadata=1; next } in_metadata && /^  name:/ { print $2; exit }' "${adapter_manifest}")"
  adapter_version="$(awk '/^metadata:/ { in_metadata=1; next } in_metadata && /^  version:/ { print $2; exit }' "${adapter_manifest}")"
  [[ -n "${adapter_stack}" && -n "${adapter_version}" ]] || {
    printf '[FAIL] adapter stack identity is incomplete: %s\n' "${adapter_manifest}" >&2
    exit 1
  }
  adapter_artifact="${repository_output}/${adapter_stack}-${adapter_version}.tgz"
  [[ -s "${adapter_artifact}" ]] || {
    printf '[FAIL] missing packaged adapter stack: %s\n' "${adapter_stack}" >&2
    exit 1
  }
  tar -tzf "${adapter_artifact}" './stack.yaml' >/dev/null
  tar -tzf "${adapter_artifact}" | grep -q '^./addons/.*\.tgz$'
  tar -xOf "${adapter_artifact}" ./stack.yaml | grep -q 'mode: bundled'
done < <(find "${REPO_DIR}/adapters" -mindepth 3 -maxdepth 3 -type f -name stack.yaml | sort)

printf '[PASS] stack packaging produces a self-contained bundled artifact\n'

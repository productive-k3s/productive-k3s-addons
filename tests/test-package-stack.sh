#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

artifact="${WORK_DIR}/base.tgz"
extract_dir="${WORK_DIR}/extract"
mkdir -p "${extract_dir}"

bash "${REPO_DIR}/scripts/package-stack.sh" --stack base --output "${artifact}"
tar -xzf "${artifact}" -C "${extract_dir}"

grep -F 'name: base' "${extract_dir}/stack.yaml" >/dev/null
grep -F 'mode: bundled' "${extract_dir}/stack.yaml" >/dev/null
grep -F 'distros:' "${extract_dir}/stack.yaml" >/dev/null
grep -F 'source: addons/cert-manager-0.1.0.tgz' "${extract_dir}/stack.yaml" >/dev/null
grep -F 'source: addons/longhorn-0.1.0.tgz' "${extract_dir}/stack.yaml" >/dev/null
grep -F 'source: addons/rancher-0.1.0.tgz' "${extract_dir}/stack.yaml" >/dev/null
grep -F 'source: addons/registry-0.1.0.tgz' "${extract_dir}/stack.yaml" >/dev/null

for addon in cert-manager longhorn rancher registry; do
  addon_artifact="${extract_dir}/addons/${addon}-0.1.0.tgz"
  [[ -s "${addon_artifact}" ]] || {
    printf '[FAIL] missing packaged add-on: %s\n' "${addon}" >&2
    exit 1
  }
  tar -tzf "${addon_artifact}" | grep -q '^\./addon.yaml$'
done

printf '[PASS] stack packaging produces a self-contained bundled artifact\n'

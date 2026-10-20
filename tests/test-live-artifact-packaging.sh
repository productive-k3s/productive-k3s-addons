#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

# shellcheck disable=SC1091
source "${REPO_DIR}/scripts/lib/artifact-packaging.sh"

ADDON_NAME="nginx"
ADDON_VERSION="$(pk3s_manifest_identity "${REPO_DIR}/addons/${ADDON_NAME}/addon.yaml" "${ADDON_NAME}")"
PREBUILT_DIR="${WORK_DIR}/prebuilt"
FAKE_CORE_DIR="${WORK_DIR}/core"
KUBECONFIG_PATH="${WORK_DIR}/kubeconfig"
mkdir -p "${PREBUILT_DIR}" "${FAKE_CORE_DIR}"
: > "${KUBECONFIG_PATH}"

PREBUILT_TGZ="${PREBUILT_DIR}/${ADDON_NAME}-${ADDON_VERSION}.tgz"
pk3s_package_addon "${REPO_DIR}" "${ADDON_NAME}" "${PREBUILT_TGZ}"
PREBUILT_DIGEST="$(sha256sum "${PREBUILT_TGZ}" | awk '{print $1}')"

cat > "${FAKE_CORE_DIR}/productive-k3s-core.sh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[[ "${1:-}" == "addon" && "${2:-}" == "install" && "${3:-}" == "--tgz" && -f "${4:-}" ]]
artifact="${4}"
revision="$(tar -xOf "${artifact}" ./addon.yaml | awk '/^  sourceRevision:/ { print $2; exit }')"
[[ "${revision}" =~ ^[0-9a-f]{40}$ ]] || {
  printf '[FAIL] live add-on artifact does not contain an immutable sourceRevision: %s\n' "${revision}" >&2
  exit 1
}

if [[ -n "${PK3S_EXPECTED_ADDON_DIGEST:-}" ]]; then
  actual_digest="$(sha256sum "${artifact}" | awk '{print $1}')"
  [[ "${actual_digest}" == "${PK3S_EXPECTED_ADDON_DIGEST}" ]] || {
    printf '[FAIL] live add-on runner did not preserve the prebuilt artifact\n' >&2
    exit 1
  }
fi
EOF
chmod +x "${FAKE_CORE_DIR}/productive-k3s-core.sh"

PK3S_PREBUILT_ADDONS_DIR="${PREBUILT_DIR}" \
PK3S_EXPECTED_ADDON_DIGEST="${PREBUILT_DIGEST}" \
KUBECONFIG="${KUBECONFIG_PATH}" \
  bash "${REPO_DIR}/tests/addons/run.sh" live "${ADDON_NAME}" "${FAKE_CORE_DIR}"

PK3S_PREBUILT_ADDONS_DIR="" \
PK3S_EXPECTED_ADDON_DIGEST="" \
KUBECONFIG="${KUBECONFIG_PATH}" \
  bash "${REPO_DIR}/tests/addons/run.sh" live "${ADDON_NAME}" "${FAKE_CORE_DIR}"

printf '[PASS] live add-on runner installs immutable packaged artifacts\n'

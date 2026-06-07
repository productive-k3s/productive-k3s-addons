#!/usr/bin/env bash
set -euo pipefail

LEVEL="${1:?level is required}"
ADDON_NAME="${2:?addon name is required}"
CORE_REPO_DIR="${3:?core repo is required}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ADDON_DIR="${REPO_DIR}/addons/${ADDON_NAME}"

case "${LEVEL}" in
  static)
    bash "${REPO_DIR}/scripts/validate-addon-package.sh" "${REPO_DIR}" --kind addon --name "${ADDON_NAME}"
    ;;
  contract)
    (cd "${CORE_REPO_DIR}" && ./productive-k3s-core.sh dev addon validate --source "${ADDON_DIR}")
    ;;
  live)
    [[ -d "${ADDON_DIR}" ]] || {
      printf '[FAIL] addon source not found: %s\n' "${ADDON_DIR}" >&2
      exit 1
    }
    [[ -n "${KUBECONFIG:-}" || -n "${PK3S_KUBE_CONTEXT:-}" ]] || {
      printf '[FAIL] live addon validation requires KUBECONFIG or PK3S_KUBE_CONTEXT\n' >&2
      exit 1
    }
    TMP_DIR="$(mktemp -d)"
    trap 'rm -rf "${TMP_DIR}"' EXIT
    ADDON_TGZ="${TMP_DIR}/${ADDON_NAME}.tgz"
    tar -czf "${ADDON_TGZ}" -C "${ADDON_DIR}" .
    cmd=(./productive-k3s-core.sh addon install --tgz "${ADDON_TGZ}")
    if [[ -n "${PK3S_KUBE_CONTEXT:-}" ]]; then
      cmd+=(--cluster-context "${PK3S_KUBE_CONTEXT}")
    else
      cmd+=(--kubeconfig "${KUBECONFIG}")
    fi
    if [[ -n "${PK3S_ADDON_PUBLIC_HOST:-}" ]]; then
      cmd+=(--public-host "${PK3S_ADDON_PUBLIC_HOST}")
    fi
    (cd "${CORE_REPO_DIR}" && "${cmd[@]}")
    ;;
  *)
    printf '[FAIL] unsupported addon test level: %s\n' "${LEVEL}" >&2
    exit 1
    ;;
esac

#!/usr/bin/env bash
set -euo pipefail

LEVEL="${1:?level is required}"
STACK_NAME="${2:?stack name is required}"
CORE_REPO_DIR="${3:?core repo is required}"
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STACK_DIR="${REPO_DIR}/stacks/${STACK_NAME}"

resolve_stack_addons() {
  awk '
    /^spec:/ { in_spec=1; next }
    in_spec && /^  addons:/ { in_addons=1; next }
    in_addons && /^    - / { sub(/^    - /, "", $0); print; next }
    in_addons && !/^    - / { exit }
  ' "${STACK_DIR}/stack.yaml"
}

case "${LEVEL}" in
  static)
    bash "${REPO_DIR}/scripts/validate-addon-package.sh" "${REPO_DIR}" --kind stack --name "${STACK_NAME}"
    ;;
  contract)
    (cd "${CORE_REPO_DIR}" && ./productive-k3s-core.sh dev stack validate --source "${STACK_DIR}")
    ;;
  live)
    [[ -n "${KUBECONFIG:-}" || -n "${PK3S_KUBE_CONTEXT:-}" ]] || {
      printf '[FAIL] live stack validation requires KUBECONFIG or PK3S_KUBE_CONTEXT\n' >&2
      exit 1
    }
    while IFS= read -r addon_name; do
      [[ -n "${addon_name}" ]] || continue
      [[ -d "${REPO_DIR}/addons/${addon_name}" ]] || {
        printf '[FAIL] stack %s references missing addon source: %s\n' "${STACK_NAME}" "${addon_name}" >&2
        exit 1
      }
      KUBECONFIG="${KUBECONFIG:-}" PK3S_KUBE_CONTEXT="${PK3S_KUBE_CONTEXT:-}" PK3S_ADDON_PUBLIC_HOST="${PK3S_ADDON_PUBLIC_HOST:-}" \
        bash "${REPO_DIR}/tests/addons/run.sh" live "${addon_name}" "${CORE_REPO_DIR}"
    done < <(resolve_stack_addons)
    ;;
  *)
    printf '[FAIL] unsupported stack test level: %s\n' "${LEVEL}" >&2
    exit 1
    ;;
esac

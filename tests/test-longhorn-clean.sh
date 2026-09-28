#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLEAN_SH="${REPO_DIR}/addons/longhorn/scripts/clean.sh"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

EVENTS="${WORK_DIR}/events.log"
FAKE_HELM="${WORK_DIR}/helm"

cat > "${FAKE_HELM}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'helm %s\n' "$*" >> "${PK3S_TEST_EVENTS:?}"
EOF
chmod +x "${FAKE_HELM}"

export PK3S_HELM_BIN="${FAKE_HELM}"
export PK3S_TEST_EVENTS="${EVENTS}"

bash -c '
  set -euo pipefail
  source "${1:?}"

  pk3s_runtime_server_active() { return 0; }
  kubectl_k3s() {
    printf "kubectl %s\n" "$*" >> "${PK3S_TEST_EVENTS:?}"
    return 0
  }
  delete_named_resources_matching() {
    printf "delete-matching %s %s\n" "$1" "$2" >> "${PK3S_TEST_EVENTS:?}"
  }

  pk3s_addon_clean
' _ "${CLEAN_SH}"

expected_order=(
  'kubectl get namespace longhorn-system'
  'kubectl -n longhorn-system get settings.longhorn.io deleting-confirmation-flag'
  'kubectl -n longhorn-system patch settings.longhorn.io deleting-confirmation-flag --type=merge -p {"value":"true"}'
  'helm status longhorn --namespace longhorn-system'
  'helm uninstall longhorn --namespace longhorn-system --wait --timeout 10m'
  'kubectl delete namespace longhorn-system --ignore-not-found --wait=false'
)

previous_line=0
for event in "${expected_order[@]}"; do
  current_line="$(grep -nFx "${event}" "${EVENTS}" | cut -d: -f1)"
  [[ -n "${current_line}" && "${current_line}" -gt "${previous_line}" ]] || {
    printf '[FAIL] Longhorn clean event is missing or out of order: %s\n' "${event}" >&2
    cat "${EVENTS}" >&2
    exit 1
  }
  previous_line="${current_line}"
done

printf '[PASS] Longhorn clean confirms deletion and uninstalls Helm before deleting the namespace\n'

: > "${EVENTS}"
bash -c '
  set -euo pipefail
  source "${1:?}"

  pk3s_runtime_server_active() { return 0; }
  kubectl_k3s() {
    printf "kubectl %s\n" "$*" >> "${PK3S_TEST_EVENTS:?}"
    if [[ "$*" == "get namespace longhorn-system" ]]; then
      return 1
    fi
    return 0
  }
  delete_named_resources_matching() {
    printf "delete-matching %s %s\n" "$1" "$2" >> "${PK3S_TEST_EVENTS:?}"
  }

  pk3s_addon_clean
' _ "${CLEAN_SH}"

if grep -q '^helm ' "${EVENTS}"; then
  printf '[FAIL] Longhorn clean invoked Helm after the namespace was already absent\n' >&2
  cat "${EVENTS}" >&2
  exit 1
fi
grep -qFx 'delete-matching crd longhorn\.io' "${EVENTS}" || {
  printf '[FAIL] Longhorn clean did not remove residual cluster-scoped resources\n' >&2
  cat "${EVENTS}" >&2
  exit 1
}

printf '[PASS] Longhorn clean remains idempotent and removes cluster-scoped residue\n'

#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLEAN_SH="${REPO_DIR}/addons/longhorn/scripts/clean.sh"
WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

EVENTS="${WORK_DIR}/events.log"
FAKE_HELM="${WORK_DIR}/helm"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  [[ ! -f "${EVENTS}" ]] || cat "${EVENTS}" >&2
  exit 1
}

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
  namespace_present=true
  clusterrole_present=true
  clusterrolebinding_present=true
  crd_present=true
  namespaced_resource_present=true

  pk3s_runtime_server_active() { return 0; }
  kubectl_k3s() {
    printf "kubectl %s\n" "$*" >> "${PK3S_TEST_EVENTS:?}"
    case "$*" in
      "get namespace longhorn-system")
        [[ "${namespace_present}" == true ]]
        ;;
      "delete namespace longhorn-system --ignore-not-found --wait=false")
        namespace_present=false
        ;;
      "get clusterroles -o name")
        [[ "${clusterrole_present}" == false ]] || \
          printf "%s\n" clusterrole.rbac.authorization.k8s.io/longhorn-role
        ;;
      "get clusterrolebindings -o name")
        [[ "${clusterrolebinding_present}" == false ]] || \
          printf "%s\n" clusterrolebinding.rbac.authorization.k8s.io/longhorn-bind
        ;;
      "get customresourcedefinitions -o name")
        [[ "${crd_present}" == false ]] || \
          printf "%s\n" customresourcedefinition.apiextensions.k8s.io/nodes.longhorn.io
        ;;
      "get customresourcedefinition.apiextensions.k8s.io/nodes.longhorn.io -n longhorn-system -o name")
        [[ "${namespaced_resource_present}" == false ]] || \
          printf "%s\n" node.longhorn.io/test-node
        ;;
      "delete clusterrole.rbac.authorization.k8s.io/longhorn-role")
        clusterrole_present=false
        ;;
      "delete clusterrolebinding.rbac.authorization.k8s.io/longhorn-bind")
        clusterrolebinding_present=false
        ;;
      "delete customresourcedefinition.apiextensions.k8s.io/nodes.longhorn.io")
        crd_present=false
        ;;
      *)
        return 0
        ;;
    esac
  }
  pk3s_longhorn_run_standalone_uninstaller() {
    printf "standalone-uninstaller\n" >> "${PK3S_TEST_EVENTS:?}"
    namespaced_resource_present=false
  }

  pk3s_addon_clean
' _ "${CLEAN_SH}"

expected_order=(
  'kubectl get namespace longhorn-system'
  'kubectl -n longhorn-system get settings.longhorn.io deleting-confirmation-flag'
  'kubectl -n longhorn-system patch settings.longhorn.io deleting-confirmation-flag --type=merge -p {"value":"true"}'
  'helm status longhorn --namespace longhorn-system'
  'helm uninstall longhorn --namespace longhorn-system --wait --timeout 15m'
  'standalone-uninstaller'
  'kubectl get validatingwebhookconfigurations -o name'
  'kubectl get mutatingwebhookconfigurations -o name'
  'kubectl get apiservices -o name'
  'kubectl delete namespace longhorn-system --ignore-not-found --wait=false'
  'kubectl delete storageclass longhorn longhorn-static longhorn-single --ignore-not-found'
  'kubectl delete csidriver driver.longhorn.io --ignore-not-found'
  'kubectl delete priorityclass longhorn-critical --ignore-not-found'
  'kubectl delete clusterrole.rbac.authorization.k8s.io/longhorn-role'
  'kubectl delete clusterrolebinding.rbac.authorization.k8s.io/longhorn-bind'
)

previous_line=0
for event in "${expected_order[@]}"; do
  current_line="$(grep -nFx "${event}" "${EVENTS}" | head -1 | cut -d: -f1)"
  [[ -n "${current_line}" && "${current_line}" -gt "${previous_line}" ]] || \
    fail "Longhorn clean event is missing or out of order: ${event}"
  previous_line="${current_line}"
done

printf '[PASS] Longhorn clean waits for namespace termination before cluster cleanup\n'

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

  pk3s_addon_clean
' _ "${CLEAN_SH}"

grep -q '^helm ' "${EVENTS}" && fail "Longhorn clean invoked Helm after the namespace was already absent"
grep -qFx 'kubectl get customresourcedefinitions -o name' "${EVENTS}" || \
  fail "Longhorn clean did not inspect residual CRDs"

printf '[PASS] Longhorn clean remains idempotent and verifies cluster-scoped residue\n'

: > "${EVENTS}"
if PK3S_LONGHORN_NAMESPACE_TIMEOUT=0 bash -c '
  set -euo pipefail
  source "${1:?}"

  pk3s_runtime_server_active() { return 0; }
  kubectl_k3s() {
    printf "kubectl %s\n" "$*" >> "${PK3S_TEST_EVENTS:?}"
    case "$*" in
      "get namespace longhorn-system") return 0 ;;
      "get customresourcedefinitions -o name")
        printf "%s\n" customresourcedefinition.apiextensions.k8s.io/nodes.longhorn.io
        ;;
      *) return 0 ;;
    esac
  }

  pk3s_addon_clean
' _ "${CLEAN_SH}" >"${WORK_DIR}/timeout.out" 2>&1; then
  fail "Longhorn clean succeeded while the namespace remained Terminating"
fi

grep -q 'Longhorn namespace did not terminate' "${WORK_DIR}/timeout.out" || \
  fail "Longhorn clean did not explain the namespace timeout"
grep -q 'Longhorn custom resources' "${WORK_DIR}/timeout.out" || \
  fail "Longhorn clean did not include custom-resource diagnostics"
grep -q -- '--force\|finalizers' "${EVENTS}" && \
  fail "Longhorn clean attempted to force namespace finalizers"

printf '[PASS] Longhorn clean fails with diagnostics without forcing finalizers\n'

: > "${EVENTS}"
if bash -c '
  set -euo pipefail
  source "${1:?}"

  pk3s_runtime_server_active() { return 0; }
  kubectl_k3s() {
    printf "kubectl %s\n" "$*" >> "${PK3S_TEST_EVENTS:?}"
    case "$*" in
      "get namespace longhorn-system") return 1 ;;
      "delete storageclass longhorn longhorn-static longhorn-single --ignore-not-found") return 1 ;;
      *) return 0 ;;
    esac
  }

  pk3s_addon_clean
' _ "${CLEAN_SH}"; then
  fail "Longhorn clean hid a cluster-scoped deletion failure"
fi

printf '[PASS] Longhorn clean propagates cluster-scoped deletion failures\n'

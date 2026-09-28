#!/usr/bin/env bash

PK3S_LONGHORN_CLEAN_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

pk3s_longhorn_resources_matching() {
  local resource_type="$1"
  local pattern="$2"
  local resources

  resources="$(kubectl_k3s get "${resource_type}" -o name)" || return 1
  grep -E "${pattern}" <<< "${resources}" || true
}

pk3s_longhorn_delete_matching() {
  local resource_type="$1"
  local pattern="$2"
  local resource_output
  local -a resources=()

  resource_output="$(pk3s_longhorn_resources_matching "${resource_type}" "${pattern}")" || return 1
  if [[ -n "${resource_output}" ]]; then
    mapfile -t resources <<< "${resource_output}"
  fi
  if (( ${#resources[@]} > 0 )); then
    kubectl_k3s delete "${resources[@]}"
  fi
}

pk3s_longhorn_namespace_diagnostics() {
  local crd

  printf '[ERROR] Longhorn namespace did not terminate within the configured timeout.\n' >&2
  printf '[ERROR] Namespace state:\n' >&2
  kubectl_k3s get namespace longhorn-system -o yaml >&2 || true
  printf '[ERROR] Namespace workloads:\n' >&2
  kubectl_k3s get all -n longhorn-system -o wide >&2 || true
  printf '[ERROR] Longhorn custom resources:\n' >&2
  while IFS= read -r crd; do
    [[ -n "${crd}" ]] || continue
    kubectl_k3s get "${crd}" -n longhorn-system -o wide >&2 || true
  done < <(pk3s_longhorn_resources_matching customresourcedefinitions 'longhorn\.io')
  printf '[ERROR] Recent namespace events:\n' >&2
  kubectl_k3s get events -n longhorn-system --sort-by=.lastTimestamp >&2 || true
}

pk3s_longhorn_wait_for_namespace_removal() {
  local timeout_secs="${PK3S_LONGHORN_NAMESPACE_TIMEOUT:-600}"
  local poll_secs="${PK3S_LONGHORN_NAMESPACE_POLL_INTERVAL:-10}"
  local start_ts now_ts
  start_ts="$(date +%s)"

  while kubectl_k3s get namespace longhorn-system >/dev/null 2>&1; do
    now_ts="$(date +%s)"
    if (( now_ts - start_ts >= timeout_secs )); then
      pk3s_longhorn_namespace_diagnostics
      return 1
    fi
    sleep "${poll_secs}"
  done
}

pk3s_longhorn_namespaced_resources() {
  local crd crds resources

  crds="$(pk3s_longhorn_resources_matching customresourcedefinitions 'longhorn\.io')" || return 1
  while IFS= read -r crd; do
    [[ -n "${crd}" ]] || continue
    resources="$(kubectl_k3s get "${crd}" -n longhorn-system -o name)" || return 1
    [[ -z "${resources}" ]] || printf '%s\n' "${resources}"
  done <<< "${crds}"
}

pk3s_longhorn_run_standalone_uninstaller() {
  local version="${PK3S_LONGHORN_VERSION:-v1.11.1}"
  local timeout="${PK3S_LONGHORN_CLEAN_TIMEOUT:-15m}"
  local manifest="${PK3S_LONGHORN_CLEAN_SCRIPT_DIR}/../uninstall/uninstall.yaml"

  if [[ ! "${version}" =~ ^v[0-9]+\.[0-9]+\.[0-9]+([.-][0-9A-Za-z.-]+)?$ ]]; then
    printf '[ERROR] Invalid Longhorn version for standalone uninstaller: %s\n' "${version}" >&2
    return 1
  fi
  if [[ ! -f "${manifest}" ]]; then
    printf '[ERROR] Packaged Longhorn uninstall manifest is missing: %s\n' "${manifest}" >&2
    return 1
  fi

  kubectl_k3s -n longhorn-system delete job longhorn-uninstall --ignore-not-found --wait=true
  sed "s|__LONGHORN_VERSION__|${version}|g" "${manifest}" | kubectl_k3s apply -f -
  if ! kubectl_k3s -n longhorn-system wait \
    --for=condition=complete job/longhorn-uninstall \
    --timeout="${timeout}"; then
    printf '[ERROR] Longhorn standalone uninstall job did not complete.\n' >&2
    kubectl_k3s -n longhorn-system get job longhorn-uninstall -o yaml >&2 || true
    kubectl_k3s -n longhorn-system logs job/longhorn-uninstall --all-containers >&2 || true
    return 1
  fi

  kubectl_k3s -n longhorn-system logs job/longhorn-uninstall --all-containers || true
  kubectl_k3s -n longhorn-system delete job longhorn-uninstall --ignore-not-found --wait=true
  kubectl_k3s -n longhorn-system delete serviceaccount longhorn-uninstall-service-account --ignore-not-found
  kubectl_k3s delete clusterrolebinding longhorn-uninstall-bind --ignore-not-found
  kubectl_k3s delete clusterrole longhorn-uninstall-role --ignore-not-found
}

pk3s_longhorn_delete_blocking_resources() {
  pk3s_longhorn_delete_matching validatingwebhookconfigurations 'longhorn'
  pk3s_longhorn_delete_matching mutatingwebhookconfigurations 'longhorn'
  pk3s_longhorn_delete_matching apiservices 'longhorn'
}

pk3s_longhorn_delete_cluster_resources() {
  pk3s_longhorn_delete_blocking_resources
  kubectl_k3s delete storageclass longhorn longhorn-static longhorn-single --ignore-not-found
  kubectl_k3s delete csidriver driver.longhorn.io --ignore-not-found
  kubectl_k3s delete priorityclass longhorn-critical --ignore-not-found
  pk3s_longhorn_delete_matching clusterroles 'longhorn'
  pk3s_longhorn_delete_matching clusterrolebindings 'longhorn'
  pk3s_longhorn_delete_matching customresourcedefinitions 'longhorn\.io'
}

pk3s_longhorn_verify_cluster_resources_absent() {
  local resource_type pattern matches
  local residue=""
  local checks=(
    'storageclasses|/longhorn(-static|-single)?$'
    'csidrivers|/driver\.longhorn\.io$'
    'priorityclasses|/longhorn-critical$'
    'validatingwebhookconfigurations|longhorn'
    'mutatingwebhookconfigurations|longhorn'
    'apiservices|longhorn'
    'clusterroles|longhorn'
    'clusterrolebindings|longhorn'
    'customresourcedefinitions|longhorn\.io'
  )

  for check in "${checks[@]}"; do
    IFS='|' read -r resource_type pattern <<< "${check}"
    matches="$(pk3s_longhorn_resources_matching "${resource_type}" "${pattern}")" || return 1
    residue+="${matches}"$'\n'
  done
  residue="$(printf '%s' "${residue}" | sed '/^[[:space:]]*$/d')"

  if [[ -n "${residue}" ]]; then
    printf '[ERROR] Longhorn cluster-scoped resources remain after cleanup:\n%s\n' "${residue}" >&2
    return 1
  fi
}

pk3s_addon_clean() {
  local helm_bin="${PK3S_HELM_BIN:-helm}"
  local helm_timeout="${PK3S_LONGHORN_CLEAN_TIMEOUT:-15m}"
  local namespaced_resources

  if ! pk3s_runtime_server_active; then
    return 0
  fi

  if kubectl_k3s get namespace longhorn-system >/dev/null 2>&1; then
    if kubectl_k3s -n longhorn-system get settings.longhorn.io deleting-confirmation-flag >/dev/null 2>&1; then
      kubectl_k3s -n longhorn-system patch settings.longhorn.io deleting-confirmation-flag \
        --type=merge -p '{"value":"true"}' >/dev/null
    fi

    if "${helm_bin}" status longhorn --namespace longhorn-system >/dev/null 2>&1; then
      "${helm_bin}" uninstall longhorn \
        --namespace longhorn-system \
        --wait \
        --timeout "${helm_timeout}"
    fi

    namespaced_resources="$(pk3s_longhorn_namespaced_resources)" || return 1
    if [[ -n "${namespaced_resources}" ]]; then
      printf '[WARN] Helm left Longhorn custom resources; running the packaged standalone uninstaller.\n' >&2
      pk3s_longhorn_run_standalone_uninstaller
    fi

    pk3s_longhorn_delete_blocking_resources
    kubectl_k3s delete namespace longhorn-system --ignore-not-found --wait=false >/dev/null
    pk3s_longhorn_wait_for_namespace_removal
  fi

  pk3s_longhorn_delete_cluster_resources
  pk3s_longhorn_verify_cluster_resources_absent
}

pk3s_longhorn_clean() {
  pk3s_addon_clean "$@"
}

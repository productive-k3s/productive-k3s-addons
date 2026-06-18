#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

CORE_REPO_DIR="${PRODUCTIVE_K3S_CORE_REPO_DIR:-}"
CORE_REPO_URL="${PRODUCTIVE_K3S_CORE_REPO_URL:-}"
CORE_REPO_REF="${PRODUCTIVE_K3S_CORE_REPO_REF:-}"
VM_NAME="${LIVE_MATRIX_VM_NAME:-pk3s-addons-live-$(date +%Y%m%d-%H%M%S)}"
REMOTE_USER="${LIVE_MATRIX_REMOTE_USER:-ubuntu}"
REMOTE_HOME="/home/${REMOTE_USER}"
REMOTE_CORE_DIR="${LIVE_MATRIX_CORE_REMOTE_DIR:-${REMOTE_HOME}/productive-k3s-core}"
REMOTE_ADDONS_DIR="${LIVE_MATRIX_ADDONS_REMOTE_DIR:-${REMOTE_HOME}/productive-k3s-addons}"
REMOTE_KUBECONFIG="${LIVE_MATRIX_REMOTE_KUBECONFIG:-${REMOTE_HOME}/.kube/config}"
KEEP_VM="${KEEP_VM:-n}"
TRANSFER_STAGING_DIR=""
TEMP_CORE_DIR=""

log() {
  printf '[INFO] %s\n' "$1"
}

err() {
  printf '[ERROR] %s\n' "$1" >&2
}

cleanup() {
  if [[ -n "${TRANSFER_STAGING_DIR}" && -d "${TRANSFER_STAGING_DIR}" ]]; then
    rm -rf "${TRANSFER_STAGING_DIR}"
  fi
  if [[ -n "${TEMP_CORE_DIR}" && -d "${TEMP_CORE_DIR}" ]]; then
    rm -rf "${TEMP_CORE_DIR}"
  fi
  if [[ "${KEEP_VM}" != "y" ]]; then
    bash "${REPO_DIR}/tests/clean-test-vms.sh" "${VM_NAME}" >/dev/null 2>&1 || true
  else
    log "VM preserved: ${VM_NAME}"
  fi
}
trap cleanup EXIT

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || {
    err "required command not found: $1"
    exit 1
  }
}

resolve_latest_core_release() {
  need_cmd curl
  need_cmd jq
  curl -fsSL "https://api.github.com/repos/jemacchi/productive-k3s-core/releases/latest" | jq -r '.tag_name // empty'
}

prepare_core_source() {
  if [[ -n "${CORE_REPO_DIR}" ]]; then
    [[ -f "${CORE_REPO_DIR}/productive-k3s-core.sh" && -d "${CORE_REPO_DIR}/tests" ]] || {
      err "invalid PRODUCTIVE_K3S_CORE_REPO_DIR: ${CORE_REPO_DIR}"
      exit 1
    }
    log "Using productive-k3s-core from directory: ${CORE_REPO_DIR}"
    return 0
  fi

  local ref="${CORE_VERSION:-${CORE_REPO_REF:-}}"
  local url="${CORE_REPO_URL:-https://github.com/jemacchi/productive-k3s-core.git}"

  if [[ -z "${ref}" ]]; then
    ref="$(resolve_latest_core_release)"
    [[ -n "${ref}" ]] || {
      err "could not resolve latest productive-k3s-core release"
      exit 1
    }
  fi

  need_cmd git
  TEMP_CORE_DIR="$(mktemp -d)"
  log "Cloning productive-k3s-core from URL: ${url} (ref: ${ref})"
  git clone --depth 1 --branch "${ref}" "${url}" "${TEMP_CORE_DIR}" >/dev/null 2>&1 || {
    err "could not clone productive-k3s-core ref ${ref} from ${url}"
    exit 1
  }
  CORE_REPO_DIR="${TEMP_CORE_DIR}"
}

stage_addons_repo() {
  local staging_parent
  staging_parent="${HOME}/pk3s-transfer-staging"
  mkdir -p "${staging_parent}"
  TRANSFER_STAGING_DIR="$(mktemp -d "${staging_parent}/staging.XXXXXX")"
  log "Staging addon repository from ${REPO_DIR}"
  tar \
    --exclude='.git' \
    --exclude='test-artifacts' \
    --exclude='docs/site' \
    --exclude='docs/.venv' \
    --exclude='.venv' \
    -czf "${TRANSFER_STAGING_DIR}/productive-k3s-addons.tar.gz" \
    -C "$(dirname "${REPO_DIR}")" \
    "$(basename "${REPO_DIR}")"
}

launch_core_vm() {
  log "Launching Ubuntu 24.04 VM through productive-k3s-core test harness"
  PRODUCTIVE_K3S_DISTRO=k3s \
    bash "${CORE_REPO_DIR}/tests/test-in-vm.sh" \
      --platform ubuntu \
      --image 24.04 \
      --profile core \
      --name "${VM_NAME}" \
      --keep-vm
}

copy_addons_repo_to_vm() {
  log "Preparing addon repository inside VM ${VM_NAME}"
  [[ -f "${TRANSFER_STAGING_DIR}/productive-k3s-addons.tar.gz" ]] || {
    err "staged addon archive not found: ${TRANSFER_STAGING_DIR}/productive-k3s-addons.tar.gz"
    exit 1
  }
  multipass exec "${VM_NAME}" -- bash -lc "rm -rf '${REMOTE_ADDONS_DIR}' && mkdir -p '${REMOTE_HOME}/.kube'"
  multipass transfer "${TRANSFER_STAGING_DIR}/productive-k3s-addons.tar.gz" "${VM_NAME}:${REMOTE_HOME}/productive-k3s-addons.tar.gz"
  multipass exec "${VM_NAME}" -- bash -lc "
    cd '${REMOTE_HOME}' &&
    tar -xzf productive-k3s-addons.tar.gz &&
    rm -f productive-k3s-addons.tar.gz
  "
}

prepare_remote_kubeconfig() {
  log "Preparing kubeconfig for remote user ${REMOTE_USER}"
  multipass exec "${VM_NAME}" -- bash -lc "
    sudo mkdir -p '${REMOTE_HOME}/.kube' &&
    sudo cp /etc/rancher/k3s/k3s.yaml '${REMOTE_KUBECONFIG}' &&
    sudo chown -R '${REMOTE_USER}:${REMOTE_USER}' '${REMOTE_HOME}/.kube'
  "
}

run_live_matrix_inside_vm() {
  log "Running addon live matrix inside VM ${VM_NAME}"
  multipass exec "${VM_NAME}" -- bash -lc "
    cd '${REMOTE_ADDONS_DIR}' &&
    PRODUCTIVE_K3S_CORE_REPO_DIR='${REMOTE_CORE_DIR}' \
    KUBECONFIG='${REMOTE_KUBECONFIG}' \
    PK3S_KUBE_CONTEXT='' \
    PK3S_ADDON_PUBLIC_HOST='${PK3S_ADDON_PUBLIC_HOST:-}' \
    make test-live-matrix
  "
}

copy_remote_artifacts_back() {
  local local_dir="${REPO_DIR}/test-artifacts/live-vm-${VM_NAME}"
  mkdir -p "${REPO_DIR}/test-artifacts"
  rm -rf "${local_dir}"
  if multipass exec "${VM_NAME}" -- bash -lc "test -d '${REMOTE_ADDONS_DIR}/test-artifacts'"; then
    multipass transfer -r "${VM_NAME}:${REMOTE_ADDONS_DIR}/test-artifacts" "${local_dir}"
    log "Copied remote live-matrix artifacts to ${local_dir}"
  fi
}

need_cmd multipass
prepare_core_source
launch_core_vm
stage_addons_repo
copy_addons_repo_to_vm
prepare_remote_kubeconfig
run_live_matrix_inside_vm
copy_remote_artifacts_back

#!/usr/bin/env bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../../scripts/addon-host-runtime.sh"

pk3s_addon_validate() {
  info "Checking in-cluster registry"
  if ! k get namespace registry >/dev/null 2>&1; then
    info "Registry is not installed; skipping registry-specific checks"
    return 0
  fi

  check_namespace_rollup "registry" "Registry"

  local pvc
  if pvc="$(safe_run k get pvc -n registry 2>/dev/null)"; then
    if printf '%s\n' "$pvc" | awk 'NR>1 && $2 != "Bound" {print}' | grep -q .; then
      record_fail "registry PVC exists but is not Bound"
      printf '%s\n' "$pvc"
    elif printf '%s\n' "$pvc" | awk 'NR>1 {print}' | grep -q .; then
      record_ok "registry PVC is Bound"
    else
      record_warn "no registry PVC found"
    fi
  fi

  if k get ingress registry -n registry >/dev/null 2>&1; then
    record_ok "registry ingress exists"
  else
    record_warn "registry ingress does not exist"
  fi

  local registry_host
  registry_host="$(k get ingress registry -n registry -o jsonpath='{.spec.rules[0].host}' 2>/dev/null || true)"
  if [[ -n "${registry_host}" ]]; then
    if getent hosts "${registry_host}" >/dev/null 2>&1; then
      record_ok "${registry_host} resolves locally"
    else
      record_warn "${registry_host} does not resolve locally"
    fi
    local registry_code
    registry_code="$(curl -k -s -o /dev/null -w '%{http_code}' --max-time 10 "https://${registry_host}/v2/" || true)"
    if [[ "${registry_code}" =~ ^(200|401)$ ]]; then
      record_ok "Registry HTTPS endpoint responds with HTTP ${registry_code}"
    else
      record_warn "Registry HTTPS endpoint did not return an expected code (got '${registry_code:-none}')"
    fi
  fi

  (( ${DOCKER_REGISTRY_TEST:-0} == 1 )) || return 0

  info "Checking registry with docker push/pull"

  if ! command -v docker >/dev/null 2>&1; then
    record_fail "docker command is not available"
    return
  fi

  local upstream_image="busybox:1.36"
  local test_image="${registry_host:-registry.home.arpa}/validate/busybox:1.36"
  local did_login="n"

  if [[ -n "${REGISTRY_USER:-}" || -n "${REGISTRY_PASSWORD:-}" ]]; then
    if [[ -z "${REGISTRY_USER:-}" || -z "${REGISTRY_PASSWORD:-}" ]]; then
      record_fail "set both REGISTRY_USER and REGISTRY_PASSWORD, or neither"
      return
    fi

    if ! printf '%s' "${REGISTRY_PASSWORD}" | docker login "${registry_host:-registry.home.arpa}" -u "${REGISTRY_USER}" --password-stdin >/dev/null 2>&1; then
      record_fail "docker login to ${registry_host:-registry.home.arpa} failed"
      return
    fi

    did_login="y"
    record_ok "docker login to ${registry_host:-registry.home.arpa} succeeded"
  fi

  if ! docker pull "${upstream_image}" >/dev/null 2>&1; then
    record_fail "docker pull ${upstream_image} failed"
    [[ "${did_login}" == "y" ]] && docker logout "${registry_host:-registry.home.arpa}" >/dev/null 2>&1 || true
    return
  fi

  if ! docker tag "${upstream_image}" "${test_image}" >/dev/null 2>&1; then
    record_fail "docker tag for registry validation image failed"
    [[ "${did_login}" == "y" ]] && docker logout "${registry_host:-registry.home.arpa}" >/dev/null 2>&1 || true
    return
  fi

  if ! docker push "${test_image}" >/dev/null 2>&1; then
    record_fail "docker push to ${registry_host:-registry.home.arpa} failed"
    [[ "${did_login}" == "y" ]] && docker logout "${registry_host:-registry.home.arpa}" >/dev/null 2>&1 || true
    docker image rm -f "${test_image}" >/dev/null 2>&1 || true
    return
  fi

  docker image rm -f "${test_image}" >/dev/null 2>&1 || true

  if ! docker pull "${test_image}" >/dev/null 2>&1; then
    record_fail "docker pull from ${registry_host:-registry.home.arpa} failed after push"
    [[ "${did_login}" == "y" ]] && docker logout "${registry_host:-registry.home.arpa}" >/dev/null 2>&1 || true
    docker image rm -f "${test_image}" >/dev/null 2>&1 || true
    return
  fi

  if [[ "${did_login}" == "y" ]]; then
    docker logout "${registry_host:-registry.home.arpa}" >/dev/null 2>&1 || true
    record_ok "docker push/pull against authenticated ${registry_host:-registry.home.arpa} succeeded"
  else
    record_ok "docker push/pull against anonymous ${registry_host:-registry.home.arpa} succeeded"
  fi
  docker image rm -f "${test_image}" >/dev/null 2>&1 || true
}

pk3s_registry_validate() {
  pk3s_addon_validate "$@"
}

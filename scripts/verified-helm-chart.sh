#!/usr/bin/env bash

pk3s_pull_verified_helm_chart() {
  local helm_bin="$1"
  local repository_alias="$2"
  local repository_url="$3"
  local chart_name="$4"
  local chart_version="$5"
  local expected_sha256="$6"
  local destination="$7"
  local archive actual_sha256

  "${helm_bin}" repo add "${repository_alias}" "${repository_url}" --force-update >/dev/null
  "${helm_bin}" repo update "${repository_alias}" >/dev/null
  "${helm_bin}" pull "${repository_alias}/${chart_name}" --version "${chart_version}" --destination "${destination}" >/dev/null

  archive="${destination}/${chart_name}-${chart_version}.tgz"
  [[ -f "${archive}" ]] || {
    printf '[ERROR] Helm chart archive was not downloaded: %s\n' "${archive}" >&2
    return 1
  }
  actual_sha256="$(sha256sum "${archive}" | awk '{print $1}')"
  if [[ "${actual_sha256}" != "${expected_sha256}" ]]; then
    printf '[ERROR] %s chart digest mismatch: expected %s, got %s\n' "${chart_name}" "${expected_sha256}" "${actual_sha256}" >&2
    return 1
  fi
  printf '%s\n' "${archive}"
}

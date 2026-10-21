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

  mapfile -t archives < <(find "${destination}" -maxdepth 1 -type f -name '*.tgz' -print)
  if [[ "${#archives[@]}" -ne 1 ]]; then
    printf '[ERROR] Expected exactly one downloaded Helm chart archive in %s, found %s\n' "${destination}" "${#archives[@]}" >&2
    return 1
  fi
  archive="${archives[0]}"
  actual_sha256="$(sha256sum "${archive}" | awk '{print $1}')"
  if [[ "${actual_sha256}" != "${expected_sha256}" ]]; then
    printf '[ERROR] %s chart digest mismatch: expected %s, got %s\n' "${chart_name}" "${expected_sha256}" "${actual_sha256}" >&2
    return 1
  fi
  printf '%s\n' "${archive}"
}

pk3s_verify_file_sha256() {
  local file="$1"
  local expected_sha256="$2"
  local label="${3:-file}"
  local actual_sha256

  [[ -f "${file}" ]] || {
    printf '[ERROR] %s was not found: %s\n' "${label}" "${file}" >&2
    return 1
  }
  actual_sha256="$(sha256sum "${file}" | awk '{print $1}')"
  if [[ "${actual_sha256}" != "${expected_sha256}" ]]; then
    printf '[ERROR] %s digest mismatch: expected %s, got %s\n' "${label}" "${expected_sha256}" "${actual_sha256}" >&2
    return 1
  fi
}

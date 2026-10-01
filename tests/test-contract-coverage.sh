#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MINIMUM="${PK3S_COVERAGE_MIN:-80}"
total=0
covered=0
failures=()

validate_lock() {
  local descriptor="$1"
  local lock
  lock="$(dirname "${descriptor}")/materials.lock.yaml"
  total=$((total + 1))
  if [[ ! -f "${lock}" ]]; then
    failures+=("${descriptor}: missing materials.lock.yaml")
    return
  fi
  if ! grep -Eq '^apiVersion:[[:space:]]+materials\.productive-k3s\.io/' "${lock}" ||
     ! grep -Eq '^kind:[[:space:]]+MaterialsLock[[:space:]]*$' "${lock}" ||
     ! grep -Eq '^[[:space:]]*materials:[[:space:]]*$' "${lock}" ||
     ! grep -Eq 'version:[[:space:]]*[^[:space:]}]+' "${lock}"; then
    failures+=("${lock}: incomplete MaterialsLock contract")
    return
  fi
  if grep -Eiq 'version:[[:space:]]*["'\'']?(latest|main|master|dev|development)["'\'']?([,[:space:]}]|$)' "${lock}"; then
    failures+=("${lock}: floating material version")
    return
  fi
  covered=$((covered + 1))
}

while IFS= read -r descriptor; do
  validate_lock "${descriptor}"
done < <(
  {
    find "${ROOT_DIR}/addons" -mindepth 2 -maxdepth 2 -type f -name addon.yaml 2>/dev/null
    find "${ROOT_DIR}/stacks" -mindepth 2 -maxdepth 2 -type f -name stack.yaml 2>/dev/null
    find "${ROOT_DIR}/adapters" -mindepth 3 -type f \( -name addon.yaml -o -name stack.yaml \) 2>/dev/null
  } | sort -u
)

if ((total == 0)); then
  printf '[INFO] Contract coverage: N/A (no publishable addons or stacks)\n'
  exit 0
fi

coverage=$((covered * 100 / total))
printf '[INFO] Contract coverage: %d%% (%d/%d publishable units); required: %s%%\n' "${coverage}" "${covered}" "${total}" "${MINIMUM}"
if (("${#failures[@]}" > 0)); then
  printf '[FAIL] %s\n' "${failures[@]}" >&2
fi
awk -v actual="${coverage}" -v minimum="${MINIMUM}" 'BEGIN { exit actual + 0 >= minimum + 0 ? 0 : 1 }'


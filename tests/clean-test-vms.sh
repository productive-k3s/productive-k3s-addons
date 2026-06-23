#!/usr/bin/env bash
set -euo pipefail

TARGET_VM="${1:-}"

if ! command -v multipass >/dev/null 2>&1; then
  printf '[INFO] multipass not found; skipping VM cleanup\n'
  exit 0
fi

cleanup_vm() {
  local vm_name="$1"
  printf '[INFO] Deleting VM: %s\n' "${vm_name}"
  multipass delete "${vm_name}" >/dev/null 2>&1 || true
}

if [[ -n "${TARGET_VM}" ]]; then
  cleanup_vm "${TARGET_VM}"
  printf '[INFO] Purging deleted Multipass instances\n'
  multipass purge >/dev/null 2>&1 || true
  exit 0
fi

mapfile -t vm_names < <(multipass list --format csv 2>/dev/null | awk -F',' 'NR > 1 {print $1}' | grep '^pk3s-addons-live-' || true)
for vm_name in "${vm_names[@]}"; do
  [[ -n "${vm_name}" ]] || continue
  cleanup_vm "${vm_name}"
done

printf '[INFO] Purging deleted Multipass instances\n'
multipass purge >/dev/null 2>&1 || true

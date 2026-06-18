#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ARTIFACTS_DIR="${TEST_ARTIFACTS_DIR:-${REPO_DIR}/test-artifacts}"
CATEGORY=""

usage() {
  printf 'usage: %s --category <local|matrix|live>\n' "$0" >&2
}

while (($# > 0)); do
  case "$1" in
    --category)
      CATEGORY="${2:-}"
      shift 2
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

[[ -n "${CATEGORY}" ]] || {
  usage
  exit 2
}

python3 - "$ARTIFACTS_DIR" "$CATEGORY" <<'PY'
import json
import pathlib
import sys

artifacts_dir = pathlib.Path(sys.argv[1])
category = sys.argv[2]

paths = sorted(artifacts_dir.glob(f"test-{category}-*.json"))
records = []
for path in paths:
    with path.open("r", encoding="utf-8") as fh:
        data = json.load(fh)
    if data.get("suite_category") == category:
        records.append(data)

if not records:
    print("Summary: 0 success, 0 failed, 0 unknown")
    sys.exit(1)

success = failed = unknown = 0
for record in records:
    suite = record.get("suite", "unknown")
    status = record.get("status", "unknown")
    if status == "success":
        success += 1
        label = "OK"
    elif status == "failed":
        failed += 1
        label = "FAIL"
    else:
        unknown += 1
        label = "UNKNOWN"
    print(f"[{label}] {category} suite={suite}")

print(f"Summary: {success} success, {failed} failed, {unknown} unknown")
sys.exit(0 if failed == 0 and unknown == 0 else 1)
PY

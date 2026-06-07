#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VALIDATOR="${REPO_DIR}/scripts/validate-addon-package.sh"

fail() {
  printf '[FAIL] %s\n' "$1" >&2
  exit 1
}

pass() {
  printf '[PASS] %s\n' "$1"
}

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

VALID_REPO="${WORK_DIR}/valid"
mkdir -p "${VALID_REPO}/addons/demo/scripts" "${VALID_REPO}/stacks/base"
cat >"${VALID_REPO}/addons/demo/addon.yaml" <<'EOF'
apiVersion: addons.productive-k3s.io/v1
kind: Addon
metadata:
  name: demo
  version: 0.1.0
spec:
  type: shell
  configure:
    script: scripts/configure.sh
  install:
    script: scripts/install.sh
  validate:
    script: scripts/validate.sh
  clean:
    script: scripts/clean.sh
  backup:
    script: scripts/backup.sh
EOF
cat >"${VALID_REPO}/addons/demo/scripts/configure.sh" <<'EOF'
#!/usr/bin/env bash
pk3s_addon_configure() {
  :
}
EOF
cat >"${VALID_REPO}/addons/demo/scripts/install.sh" <<'EOF'
#!/usr/bin/env bash
pk3s_addon_install() {
  :
}
EOF
cat >"${VALID_REPO}/addons/demo/scripts/validate.sh" <<'EOF'
#!/usr/bin/env bash
pk3s_addon_validate() {
  :
}
EOF
cat >"${VALID_REPO}/addons/demo/scripts/clean.sh" <<'EOF'
#!/usr/bin/env bash
pk3s_addon_clean() {
  :
}
EOF
cat >"${VALID_REPO}/addons/demo/scripts/backup.sh" <<'EOF'
#!/usr/bin/env bash
pk3s_addon_backup() {
  :
}
EOF
chmod +x "${VALID_REPO}/addons/demo/scripts/configure.sh"
chmod +x "${VALID_REPO}/addons/demo/scripts/install.sh"
chmod +x "${VALID_REPO}/addons/demo/scripts/validate.sh"
chmod +x "${VALID_REPO}/addons/demo/scripts/clean.sh"
chmod +x "${VALID_REPO}/addons/demo/scripts/backup.sh"
cat >"${VALID_REPO}/stacks/base/stack.yaml" <<'EOF'
apiVersion: addons.productive-k3s.io/v1
kind: Stack
metadata:
  name: base
  version: 0.1.0
spec:
  addons:
    - demo
EOF

bash "${VALIDATOR}" "${VALID_REPO}" >/dev/null || fail "validator rejected a repo with addon and stack sources"
pass "validator accepts addon and stack source layout"

MISSING_STACK_REPO="${WORK_DIR}/missing-stack"
mkdir -p "${MISSING_STACK_REPO}/addons/demo/scripts" "${MISSING_STACK_REPO}/stacks/base"
cp "${VALID_REPO}/addons/demo/addon.yaml" "${MISSING_STACK_REPO}/addons/demo/addon.yaml"
cp "${VALID_REPO}/addons/demo/scripts/configure.sh" "${MISSING_STACK_REPO}/addons/demo/scripts/configure.sh"
cp "${VALID_REPO}/addons/demo/scripts/install.sh" "${MISSING_STACK_REPO}/addons/demo/scripts/install.sh"
cp "${VALID_REPO}/addons/demo/scripts/validate.sh" "${MISSING_STACK_REPO}/addons/demo/scripts/validate.sh"
cp "${VALID_REPO}/addons/demo/scripts/clean.sh" "${MISSING_STACK_REPO}/addons/demo/scripts/clean.sh"
cp "${VALID_REPO}/addons/demo/scripts/backup.sh" "${MISSING_STACK_REPO}/addons/demo/scripts/backup.sh"
if bash "${VALIDATOR}" "${MISSING_STACK_REPO}" >/tmp/productive-k3s-addons-validate.out 2>&1; then
  fail "validator unexpectedly accepted stack source without stack.yaml"
fi
grep -q "missing stack.yaml" /tmp/productive-k3s-addons-validate.out || fail "validator did not report missing stack.yaml"
pass "validator rejects stack sources without stack.yaml"

MISSING_ADDON_REPO="${WORK_DIR}/missing-addon-ref"
mkdir -p "${MISSING_ADDON_REPO}/addons/demo/scripts" "${MISSING_ADDON_REPO}/stacks/base"
cp "${VALID_REPO}/addons/demo/addon.yaml" "${MISSING_ADDON_REPO}/addons/demo/addon.yaml"
cp "${VALID_REPO}/addons/demo/scripts/configure.sh" "${MISSING_ADDON_REPO}/addons/demo/scripts/configure.sh"
cp "${VALID_REPO}/addons/demo/scripts/install.sh" "${MISSING_ADDON_REPO}/addons/demo/scripts/install.sh"
cp "${VALID_REPO}/addons/demo/scripts/validate.sh" "${MISSING_ADDON_REPO}/addons/demo/scripts/validate.sh"
cp "${VALID_REPO}/addons/demo/scripts/clean.sh" "${MISSING_ADDON_REPO}/addons/demo/scripts/clean.sh"
cp "${VALID_REPO}/addons/demo/scripts/backup.sh" "${MISSING_ADDON_REPO}/addons/demo/scripts/backup.sh"
cat >"${MISSING_ADDON_REPO}/stacks/base/stack.yaml" <<'EOF'
apiVersion: addons.productive-k3s.io/v1
kind: Stack
metadata:
  name: base
  version: 0.1.0
spec:
  addons:
    - demo
    - missing-addon
EOF
if bash "${VALIDATOR}" "${MISSING_ADDON_REPO}" >/tmp/productive-k3s-addons-missing-addon.out 2>&1; then
  fail "validator unexpectedly accepted stack source with missing addon reference"
fi
grep -q "references missing addon" /tmp/productive-k3s-addons-missing-addon.out || fail "validator did not report missing addon references"
pass "validator rejects stack sources with missing addon references"

MISSING_SCRIPT_REPO="${WORK_DIR}/missing-script"
mkdir -p "${MISSING_SCRIPT_REPO}/addons/demo/scripts" "${MISSING_SCRIPT_REPO}/stacks/base"
cp "${VALID_REPO}/addons/demo/addon.yaml" "${MISSING_SCRIPT_REPO}/addons/demo/addon.yaml"
cp "${VALID_REPO}/addons/demo/scripts/install.sh" "${MISSING_SCRIPT_REPO}/addons/demo/scripts/install.sh"
cp "${VALID_REPO}/stacks/base/stack.yaml" "${MISSING_SCRIPT_REPO}/stacks/base/stack.yaml"
if bash "${VALIDATOR}" "${MISSING_SCRIPT_REPO}" >/tmp/productive-k3s-addons-missing-script.out 2>&1; then
  fail "validator unexpectedly accepted addon source with missing declared script"
fi
grep -q "declares missing script" /tmp/productive-k3s-addons-missing-script.out || fail "validator did not report missing declared script"
pass "validator rejects addon sources with missing declared scripts"

MISSING_HOOK_REPO="${WORK_DIR}/missing-hook"
mkdir -p "${MISSING_HOOK_REPO}/addons/demo/scripts" "${MISSING_HOOK_REPO}/stacks/base"
cp "${VALID_REPO}/addons/demo/addon.yaml" "${MISSING_HOOK_REPO}/addons/demo/addon.yaml"
cp "${VALID_REPO}/addons/demo/scripts/configure.sh" "${MISSING_HOOK_REPO}/addons/demo/scripts/configure.sh"
cp "${VALID_REPO}/addons/demo/scripts/validate.sh" "${MISSING_HOOK_REPO}/addons/demo/scripts/validate.sh"
cp "${VALID_REPO}/addons/demo/scripts/clean.sh" "${MISSING_HOOK_REPO}/addons/demo/scripts/clean.sh"
cp "${VALID_REPO}/addons/demo/scripts/backup.sh" "${MISSING_HOOK_REPO}/addons/demo/scripts/backup.sh"
cp "${VALID_REPO}/stacks/base/stack.yaml" "${MISSING_HOOK_REPO}/stacks/base/stack.yaml"
cat >"${MISSING_HOOK_REPO}/addons/demo/scripts/install.sh" <<'EOF'
#!/usr/bin/env bash
echo "missing hook"
EOF
chmod +x "${MISSING_HOOK_REPO}/addons/demo/scripts/install.sh"
if bash "${VALIDATOR}" "${MISSING_HOOK_REPO}" >/tmp/productive-k3s-addons-missing-hook.out 2>&1; then
  fail "validator unexpectedly accepted addon source without standardized install hook"
fi
grep -q "does not define required hook" /tmp/productive-k3s-addons-missing-hook.out || fail "validator did not report missing standardized hook"
pass "validator rejects addon sources without standardized hook functions"

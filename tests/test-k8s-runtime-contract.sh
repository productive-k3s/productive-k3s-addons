#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUNTIME_SH="${REPO_DIR}/scripts/addon-host-runtime.sh"

pass() {
  printf '[PASS] %s\n' "$1"
}

WORK_DIR="$(mktemp -d)"
trap 'rm -rf "${WORK_DIR}"' EXIT

FAKE_KUBECTL="${WORK_DIR}/fake-kubectl"
KUBECTL_LOG="${WORK_DIR}/kubectl.log"
OUTPUT_CERT="${WORK_DIR}/ca.crt"

cat > "${FAKE_KUBECTL}" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" > "${KUBECTL_LOG:?}"
printf 'Q0VSVERBVEE='
EOF
chmod +x "${FAKE_KUBECTL}"

export PK3S_KUBECTL_MODE="kubectl"
export PK3S_KUBECTL_BIN="${FAKE_KUBECTL}"
export KUBECTL_LOG

source "${RUNTIME_SH}"

sudo() {
  if [[ "${1:-}" == "tee" ]]; then
    cat > "${2:?}"
    return 0
  fi
  if [[ "${1:-}" == "k3s" ]]; then
    printf '[FAIL] runtime helper unexpectedly tried to invoke sudo k3s kubectl\n' >&2
    exit 1
  fi
  command "$@"
}

pk3s_export_tls_secret_cert "registry" "registry-tls" "${OUTPUT_CERT}"

[[ -f "${OUTPUT_CERT}" ]] || {
  printf '[FAIL] runtime helper did not write exported cert\n' >&2
  exit 1
}
[[ "$(cat "${OUTPUT_CERT}")" == "CERTDATA" ]] || {
  printf '[FAIL] runtime helper wrote unexpected cert contents\n' >&2
  exit 1
}
grep -q -- "-n registry get secret registry-tls" "${KUBECTL_LOG}" || {
  printf '[FAIL] runtime helper did not invoke the configured kubectl binary\n' >&2
  cat "${KUBECTL_LOG}" >&2
  exit 1
}
pass "addon runtime exports TLS certs through configured kubectl runtime"

NGINX_CLEAN_SH="${REPO_DIR}/addons/nginx/scripts/clean.sh"
NGINX_MARKER="${WORK_DIR}/nginx-clean.marker"

bash -lc "
  set -euo pipefail
  source '${RUNTIME_SH}'
  source '${NGINX_CLEAN_SH}'
  pk3s_runtime_server_active() { return 0; }
  kubectl_k3s() { printf 'cleaned' > '${NGINX_MARKER}'; }
  pk3s_addon_clean
" || {
  printf '[FAIL] nginx clean script is not runtime-aware\n' >&2
  exit 1
}

[[ -f "${NGINX_MARKER}" ]] || {
  printf '[FAIL] nginx clean script did not use kubectl helper\n' >&2
  exit 1
}
pass "nginx clean script uses runtime-aware server detection"

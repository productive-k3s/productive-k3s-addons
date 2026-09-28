#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${1:-}"
KIND=""
NAME=""

usage() {
  echo "Usage: $0 <repo-dir> [--kind addon|stack] [--name <name>]" >&2
}

if [[ -z "${REPO_DIR}" ]]; then
  usage
  exit 1
fi
shift || true

while (($# > 0)); do
  case "$1" in
    --kind)
      KIND="${2:-}"
      shift 2
      ;;
    --name)
      NAME="${2:-}"
      shift 2
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

[[ -d "${REPO_DIR}/addons" ]] || {
  echo "Missing addons directory: ${REPO_DIR}/addons" >&2
  exit 1
}
[[ -d "${REPO_DIR}/stacks" ]] || {
  echo "Missing stacks directory: ${REPO_DIR}/stacks" >&2
  exit 1
}

validate_addon_dir() {
  local addon_dir="$1"
  local required_section required_script hook_name
  [[ -f "${addon_dir}/addon.yaml" ]] || {
    echo "Publishable addon source missing addon.yaml: ${addon_dir}" >&2
    exit 1
  }

  for required_section in configure install validate clean backup; do
    if ! awk -v section="${required_section}" '
      /^spec:/ { in_spec=1; next }
      in_spec && $0 == "  " section ":" { found=1; exit }
      in_spec && /^[^ ]/ { exit }
      END { exit found ? 0 : 1 }
    ' "${addon_dir}/addon.yaml"; then
      echo "Publishable addon source missing required spec.${required_section}.script declaration: ${addon_dir}" >&2
      exit 1
    fi
  done

  for required_section in cluster host summary; do
    if ! awk -v section="${required_section}" '
      /^spec:/ { in_spec=1; next }
      in_spec && /^  impact:/ { in_impact=1; next }
      in_impact && $0 ~ ("^    " section ":") { found=1; exit }
      in_impact && /^[^ ]/ { exit }
      END { exit found ? 0 : 1 }
    ' "${addon_dir}/addon.yaml"; then
      echo "Publishable addon source missing required spec.impact.${required_section} declaration: ${addon_dir}" >&2
      exit 1
    fi
  done

  local host_enabled
  host_enabled="$(awk '
    /^spec:/ { in_spec=1; next }
    in_spec && /^  impact:/ { in_impact=1; next }
    in_impact && /^    host:/ { sub(/^    host:[[:space:]]*/, "", $0); print; exit }
    in_impact && /^[^ ]/ { exit }
  ' "${addon_dir}/addon.yaml")"
  if [[ "${host_enabled}" == "true" ]]; then
    if ! awk '
      /^spec:/ { in_spec=1; next }
      in_spec && /^  impact:/ { in_impact=1; next }
      in_impact && /^    hostCapabilities:/ { in_caps=1; next }
      in_caps && /^      - / { found=1; exit }
      in_caps && !/^      - / { exit }
      END { exit found ? 0 : 1 }
    ' "${addon_dir}/addon.yaml"; then
      echo "Publishable addon source with spec.impact.host=true must declare spec.impact.hostCapabilities entries: ${addon_dir}" >&2
      exit 1
    fi
  fi

  validate_addon_stack_runtime_inputs "${addon_dir}/addon.yaml" "${addon_dir}"

  while IFS= read -r required_script; do
    [[ -n "${required_script}" ]] || continue
    [[ -f "${addon_dir}/${required_script}" ]] || {
      echo "Publishable addon source declares missing script '${required_script}': ${addon_dir}" >&2
      exit 1
    }
  done < <(
    awk '
      /^spec:/ { in_spec=1; next }
      in_spec && /^  configure:/ { subsection="configure"; next }
      in_spec && /^  install:/ { subsection="install"; next }
      in_spec && /^  validate:/ { subsection="validate"; next }
      in_spec && /^  clean:/ { subsection="clean"; next }
      in_spec && /^  backup:/ { subsection="backup"; next }
      in_spec && subsection != "" && /^    script:/ { sub(/^    script:[[:space:]]*/, "", $0); print; subsection=""; next }
    ' "${addon_dir}/addon.yaml"
  )

  while IFS='|' read -r required_script hook_name; do
    [[ -n "${required_script}" ]] || continue
    if ! grep -Eq "^[[:space:]]*${hook_name}[[:space:]]*\\(\\)" "${addon_dir}/${required_script}"; then
      echo "Publishable addon source script '${required_script}' does not define required hook '${hook_name}': ${addon_dir}" >&2
      exit 1
    fi
  done <<'EOF'
scripts/configure.sh|pk3s_addon_configure
scripts/install.sh|pk3s_addon_install
scripts/validate.sh|pk3s_addon_validate
scripts/clean.sh|pk3s_addon_clean
scripts/backup.sh|pk3s_addon_backup
EOF
}

validate_addon_stack_runtime_inputs() {
  local manifest="$1"
  local addon_dir="$2"
  local name source value_from default_value required

  while IFS='|' read -r name source value_from default_value required; do
    [[ -n "${name}" ]] || continue
    [[ "${name}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || {
      echo "Publishable addon source has invalid stack runtime input name '${name}': ${addon_dir}" >&2
      exit 1
    }
    if [[ -n "${source}" && ! "${source}" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      echo "Publishable addon source has invalid stack runtime input source '${source}' for '${name}': ${addon_dir}" >&2
      exit 1
    fi
    case "${value_from}" in
      ""|core.clusterIssuerAction|core.tlsSource)
        ;;
      *)
        echo "Publishable addon source has unsupported stack runtime valueFrom '${value_from}' for '${name}': ${addon_dir}" >&2
        exit 1
        ;;
    esac
    if [[ -z "${source}" && -z "${value_from}" && -z "${default_value}" ]]; then
      echo "Publishable addon source stack runtime input '${name}' must declare source, valueFrom, or default: ${addon_dir}" >&2
      exit 1
    fi
    case "${required}" in
      ""|true|false)
        ;;
      *)
        echo "Publishable addon source stack runtime input '${name}' has invalid required value '${required}': ${addon_dir}" >&2
        exit 1
        ;;
    esac
  done < <(
    awk '
      function trim(value) {
        sub(/^[[:space:]]+/, "", value)
        sub(/[[:space:]]+$/, "", value)
        if (value ~ /^".*"$/) {
          sub(/^"/, "", value)
          sub(/"$/, "", value)
        }
        return value
      }
      function flush_record() {
        if (current_name != "") {
          printf "%s|%s|%s|%s|%s\n", current_name, current_source, current_value_from, current_default, current_required
        }
        current_name=""
        current_source=""
        current_value_from=""
        current_default=""
        current_required=""
      }
      /^spec:/ { in_spec=1; in_pk3s=0; in_stack=0; in_runtime=0; in_inputs=0; next }
      in_spec && /^  productiveK3s:/ { in_pk3s=1; in_stack=0; in_runtime=0; in_inputs=0; next }
      in_pk3s && /^    stack:/ { in_stack=1; in_runtime=0; in_inputs=0; next }
      in_stack && /^      runtime:/ { in_runtime=1; in_inputs=0; next }
      in_runtime && /^        inputs:/ { in_inputs=1; next }
      in_inputs && /^          - name:/ {
        flush_record()
        line=$0
        sub(/^          - name:[[:space:]]*/, "", line)
        current_name=trim(line)
        next
      }
      in_inputs && current_name != "" && /^            source:/ {
        line=$0
        sub(/^            source:[[:space:]]*/, "", line)
        current_source=trim(line)
        next
      }
      in_inputs && current_name != "" && /^            valueFrom:/ {
        line=$0
        sub(/^            valueFrom:[[:space:]]*/, "", line)
        current_value_from=trim(line)
        next
      }
      in_inputs && current_name != "" && /^            default:/ {
        line=$0
        sub(/^            default:[[:space:]]*/, "", line)
        current_default=trim(line)
        next
      }
      in_inputs && current_name != "" && /^            required:/ {
        line=$0
        sub(/^            required:[[:space:]]*/, "", line)
        current_required=trim(line)
        next
      }
      in_inputs && /^[^ ]/ { flush_record(); exit }
      in_inputs && /^  [^ ]/ { flush_record(); exit }
      in_inputs && /^    [^ ]/ { flush_record(); exit }
      in_inputs && /^      [^ ]/ { flush_record(); exit }
      in_inputs && /^        [^ ]/ { flush_record(); exit }
      END { flush_record() }
    ' "${manifest}"
  )
}

validate_stack_dir() {
  local stack_dir="$1"
  [[ -f "${stack_dir}/stack.yaml" ]] || {
    echo "Publishable stack source missing stack.yaml: ${stack_dir}" >&2
    exit 1
  }
  while IFS= read -r addon_name; do
    [[ -n "${addon_name}" ]] || continue
    [[ -d "${REPO_DIR}/addons/${addon_name}" ]] || {
      echo "Publishable stack source references missing addon: ${stack_dir} -> ${addon_name}" >&2
      exit 1
    }
  done < <(
    awk '
      /^spec:/ { in_spec=1; next }
      in_spec && /^  addons:/ { in_addons=1; next }
      in_addons && /^    - / { sub(/^    - /, "", $0); print; next }
      in_addons && !/^    - / { exit }
    ' "${stack_dir}/stack.yaml"
  )
}

if [[ -n "${NAME}" && -z "${KIND}" ]]; then
  echo "--name requires --kind addon|stack" >&2
  exit 1
fi

case "${KIND}" in
  addon)
    [[ -n "${NAME}" ]] || {
      echo "--kind addon requires --name <name>" >&2
      exit 1
    }
    validate_addon_dir "${REPO_DIR}/addons/${NAME}"
    ;;
  stack)
    [[ -n "${NAME}" ]] || {
      echo "--kind stack requires --name <name>" >&2
      exit 1
    }
    validate_stack_dir "${REPO_DIR}/stacks/${NAME}"
    ;;
  "")
    while IFS= read -r addon_dir; do
      validate_addon_dir "${addon_dir}"
    done < <(find "${REPO_DIR}/addons" -mindepth 1 -maxdepth 1 -type d | sort)
    while IFS= read -r stack_dir; do
      validate_stack_dir "${stack_dir}"
    done < <(find "${REPO_DIR}/stacks" -mindepth 1 -maxdepth 1 -type d | sort)
    ;;
  *)
    echo "Unsupported kind: ${KIND}" >&2
    exit 1
    ;;
esac

echo "Addon and stack repository source layout is valid: ${REPO_DIR}"

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

#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

bootstrap_repo_venv() {
  local label=$1
  local repo=$2
  local requirements_file=$3
  local requested_python=${4:-}
  local python_bin=""
  local selected_minor=""
  local existing_minor=""
  local venv_dir="$repo/.venv"

  require_dir "$repo"
  require_file "$repo/$requirements_file"

  python_bin="$(select_supported_python "$requested_python")"
  selected_minor="$(python_minor_version "$python_bin")"

  if [[ -x "$venv_dir/bin/python" ]]; then
    existing_minor="$(python_minor_version "$venv_dir/bin/python")"
  fi

  section "Bootstrap $label"
  printf 'Repo:              %s\n' "$repo"
  printf 'Selected Python:   %s (%s)\n' "$python_bin" "$selected_minor"

  if [[ -n "$existing_minor" && "$existing_minor" != "$selected_minor" ]]; then
    printf 'Replacing .venv:   existing minor %s -> %s\n' "$existing_minor" "$selected_minor"
    rm -rf "$venv_dir"
  fi

  if [[ ! -x "$venv_dir/bin/python" ]]; then
    "$python_bin" -m venv "$venv_dir"
  fi

  "$venv_dir/bin/python" -m pip install --upgrade pip
  "$venv_dir/bin/python" -m pip install -r "$repo/$requirements_file"

  require_supported_venv_python "$label venv" "$venv_dir/bin/python"
}

section "Python Bootstrap Plan"
printf 'This script rebuilds the local Python service venvs with a supported interpreter.\n'
printf 'Preference order:  python3.11, then python3.10, then python3.9.\n'
printf 'Per-repo override: AUTH_PYTHON_BIN, ISSUER_PYTHON_BIN, FRONTEND_PYTHON_BIN.\n'

bootstrap_repo_venv "auth" "$AUTH_REPO" "requirements.txt" "${AUTH_PYTHON_BIN:-}"
bootstrap_repo_venv "issuer" "$ISSUER_REPO" "app/requirements.txt" "${ISSUER_PYTHON_BIN:-}"
bootstrap_repo_venv "frontend" "$FRONTEND_REPO" "app/requirements.txt" "${FRONTEND_PYTHON_BIN:-}"

section "Bootstrap Complete"
printf 'Local Python service venvs are ready.\n'
printf 'Next step: %s/build-local-all.sh\n' "$SCRIPT_DIR"
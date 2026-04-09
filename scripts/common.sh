#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PROJECT_DOCS_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
CODE_ROOT_DEFAULT=$(CDPATH= cd -- "$PROJECT_DOCS_DIR/.." && pwd)
LOCAL_DEMO_ENV_DEFAULT="$SCRIPT_DIR/local-demo.env"

if [[ -f "${LOCAL_DEMO_ENV:-$LOCAL_DEMO_ENV_DEFAULT}" ]]; then
  # shellcheck source=/dev/null
  source "${LOCAL_DEMO_ENV:-$LOCAL_DEMO_ENV_DEFAULT}"
fi

CODE_ROOT="${CODE_ROOT:-$CODE_ROOT_DEFAULT}"

WALLET_REPO="${WALLET_REPO:-$CODE_ROOT/eudi-app-android-wallet-ui}"
AUTH_REPO="${AUTH_REPO:-$CODE_ROOT/eudi-srv-issuer-oidc-py}"
ISSUER_REPO="${ISSUER_REPO:-$CODE_ROOT/eudi-srv-web-issuing-eudiw-py}"
FRONTEND_REPO="${FRONTEND_REPO:-$CODE_ROOT/eudi-srv-web-issuing-frontend-eudiw-py}"
VERIFIER_REPO="${VERIFIER_REPO:-$CODE_ROOT/av-srv-web-verifier-endpoint-23220-4-kt}"
VERIFIER_UI_REPO="${VERIFIER_UI_REPO:-$CODE_ROOT/eudi-web-verifier}"

detect_lan_ip() {
  ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true
}

detect_adb_bin() {
  local candidate="${ADB_BIN:-}"

  if [[ -n "$candidate" ]] && [[ -x "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return
  fi

  for candidate in \
    "${ANDROID_SDK_ROOT:-}/platform-tools/adb" \
    "${ANDROID_HOME:-}/platform-tools/adb" \
    "$HOME/Library/Android/sdk/platform-tools/adb"
  do
    if [[ -n "$candidate" ]] && [[ -x "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  if command -v adb >/dev/null 2>&1; then
    command -v adb
    return
  fi

  printf '%s\n' "$HOME/Library/Android/sdk/platform-tools/adb"
}

detect_android_sdk_dir() {
  local candidate="${ANDROID_SDK_DIR:-}"

  if [[ -n "$candidate" ]] && [[ -d "$candidate" ]]; then
    printf '%s\n' "$candidate"
    return
  fi

  for candidate in \
    "${ANDROID_SDK_ROOT:-}" \
    "${ANDROID_HOME:-}" \
    "$HOME/Library/Android/sdk"
  do
    if [[ -n "$candidate" ]] && [[ -d "$candidate" ]]; then
      printf '%s\n' "$candidate"
      return
    fi
  done
}

DETECTED_LAN_IP="$(detect_lan_ip)"
AUTO_DETECT_HOST_IP="${AUTO_DETECT_HOST_IP:-true}"
CONFIGURED_PUBLIC_HOST="${PUBLIC_HOST:-}"
CONFIGURED_VERIFIER_PUBLIC_HOST="${VERIFIER_PUBLIC_HOST:-}"

case "$AUTO_DETECT_HOST_IP" in
  [Tt][Rr][Uu][Ee]|1|[Yy][Ee][Ss]|[Oo][Nn])
    PUBLIC_HOST="${DETECTED_LAN_IP:-${CONFIGURED_PUBLIC_HOST:-127.0.0.1}}"
    VERIFIER_PUBLIC_HOST="${DETECTED_LAN_IP:-${CONFIGURED_VERIFIER_PUBLIC_HOST:-$PUBLIC_HOST}}"
    HOST_IP_SOURCE="auto-detected"
    ;;
  *)
    PUBLIC_HOST="${CONFIGURED_PUBLIC_HOST:-${DETECTED_LAN_IP:-127.0.0.1}}"
    VERIFIER_PUBLIC_HOST="${CONFIGURED_VERIFIER_PUBLIC_HOST:-$PUBLIC_HOST}"
    HOST_IP_SOURCE="local-demo.env/manual override"
    ;;
esac

AUTH_PORT="${AUTH_PORT:-5001}"
ISSUER_PORT="${ISSUER_PORT:-5002}"
FRONTEND_PORT="${FRONTEND_PORT:-5003}"

AUTH_URL="${AUTH_URL:-https://$PUBLIC_HOST:$AUTH_PORT}"
ISSUER_URL="${ISSUER_URL:-https://$PUBLIC_HOST:$ISSUER_PORT}"
FRONTEND_URL="${FRONTEND_URL:-https://$PUBLIC_HOST:$FRONTEND_PORT}"
VERIFIER_PUBLIC_URL="${VERIFIER_PUBLIC_URL:-https://$VERIFIER_PUBLIC_HOST}"

SHARED_CERT_FILE="${SHARED_CERT_FILE:-$ISSUER_REPO/local/runtime/runtime-ec.crt}"
SHARED_KEY_FILE="${SHARED_KEY_FILE:-$ISSUER_REPO/local/runtime/runtime-ec.key}"

ADB_BIN="${ADB_BIN:-$(detect_adb_bin)}"
ANDROID_SDK_DIR="${ANDROID_SDK_DIR:-$(detect_android_sdk_dir)}"
APK_PATH="${APK_PATH:-$WALLET_REPO/app/build/outputs/apk/demo/debug/app-demo-debug.apk}"
ANDROID_SERIAL="${ANDROID_SERIAL:-}"

case "$ANDROID_SERIAL" in
  "''"|'""') ANDROID_SERIAL="" ;;
esac

ADB_TARGET_LABEL="${ANDROID_SERIAL:-default adb target}"

LOCAL_STATE_DIR="${LOCAL_STATE_DIR:-$PROJECT_DOCS_DIR/.local}"
LOG_DIR="${LOG_DIR:-$LOCAL_STATE_DIR/logs}"
PID_DIR="${PID_DIR:-$LOCAL_STATE_DIR/pids}"
DEFAULT_LOG_FILES=("$LOG_DIR/auth-server.log" "$LOG_DIR/issuer-backend.log" "$LOG_DIR/issuer-frontend.log")

mkdir -p "$LOG_DIR" "$PID_DIR"
touch "${DEFAULT_LOG_FILES[@]}"

section() {
  printf '\n== %s ==\n' "$1"
}

info() {
  printf '%s\n' "$1"
}

fail() {
  printf 'ERROR: %s\n' "$1" >&2
  exit 1
}

require_dir() {
  [[ -d "$1" ]] || fail "Required directory not found: $1"
}

require_file() {
  [[ -f "$1" ]] || fail "Required file not found: $1"
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || fail "Required command not found: $1"
}

python_minor_version() {
  "$1" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")'
}

is_supported_python_minor() {
  case "$1" in
    3.9|3.10|3.11) return 0 ;;
    *) return 1 ;;
  esac
}

select_supported_python() {
  local requested="${1:-${PYTHON_BIN:-}}"
  local candidate=""
  local minor=""

  if [[ -n "$requested" ]]; then
    command -v "$requested" >/dev/null 2>&1 || fail "Requested Python interpreter not found: $requested"
    minor="$(python_minor_version "$requested")"
    is_supported_python_minor "$minor" || fail "Requested Python interpreter must be 3.9, 3.10, or 3.11: $requested ($minor)"
    printf '%s\n' "$requested"
    return
  fi

  for candidate in python3.11 python3.10 python3.9; do
    if command -v "$candidate" >/dev/null 2>&1; then
      printf '%s\n' "$candidate"
      return
    fi
  done

  fail "No supported Python interpreter found. Install python3.11, python3.10, or python3.9."
}

require_supported_venv_python() {
  local label=$1
  local python_path=$2
  local minor=""

  require_file "$python_path"
  minor="$(python_minor_version "$python_path")"
  is_supported_python_minor "$minor" || fail "$label must use Python 3.9, 3.10, or 3.11: $python_path ($minor)"
  printf '[ok]   %-12s %s (%s)\n' "$label" "$python_path" "$minor"
}

sync_wallet_local_properties() {
  local properties_file="$WALLET_REPO/local.properties"
  local temp_file

  temp_file=$(mktemp)

  if [[ -f "$properties_file" ]]; then
    awk -v host="$PUBLIC_HOST" -v sdk_dir="$ANDROID_SDK_DIR" '
      BEGIN { updated = 0; sdk_updated = 0 }
      /^sdk\.dir=/ {
        if (sdk_dir != "") {
          print "sdk.dir=" sdk_dir
          sdk_updated = 1
        }
        next
      }
      /^localDemoHost=/ {
        print "localDemoHost=" host
        updated = 1
        next
      }
      { print }
      END {
        if (sdk_dir != "" && !sdk_updated) {
          print "sdk.dir=" sdk_dir
        }
        if (!updated) {
          print "localDemoHost=" host
        }
      }
    ' "$properties_file" > "$temp_file"
  else
    {
      if [[ -n "$ANDROID_SDK_DIR" ]]; then
        printf 'sdk.dir=%s\n' "$ANDROID_SDK_DIR"
      fi
      printf 'localDemoHost=%s\n' "$PUBLIC_HOST"
    } > "$temp_file"
  fi

  mv "$temp_file" "$properties_file"
  printf '[ok]   wallet localDemoHost %s\n' "$PUBLIC_HOST"
  if [[ -n "$ANDROID_SDK_DIR" ]]; then
    printf '[ok]   wallet sdk.dir  %s\n' "$ANDROID_SDK_DIR"
  else
    printf '[warn] wallet sdk.dir not set automatically; define ANDROID_SDK_DIR, ANDROID_SDK_ROOT, or ANDROID_HOME if Gradle cannot find the Android SDK\n'
  fi
}

print_runtime_summary() {
  section "Runtime Summary"
  printf 'Wallet repo:        %s\n' "$WALLET_REPO"
  printf 'LAN IP source:      %s\n' "$HOST_IP_SOURCE"
  printf 'Detected LAN IP:    %s\n' "${DETECTED_LAN_IP:-unavailable}"
  printf 'Auth URL:           %s\n' "$AUTH_URL"
  printf 'Issuer URL:         %s\n' "$ISSUER_URL"
  printf 'Frontend URL:       %s\n' "$FRONTEND_URL"
  printf 'Verifier URL:       %s\n' "$VERIFIER_PUBLIC_URL"
  printf 'Shared cert:        %s\n' "$SHARED_CERT_FILE"
  printf 'APK path:           %s\n' "$APK_PATH"
  printf 'ADB bin:            %s\n' "$ADB_BIN"
  printf 'Android SDK dir:    %s\n' "${ANDROID_SDK_DIR:-unavailable}"
  printf 'ADB target:         %s\n' "$ADB_TARGET_LABEL"
  printf 'Log dir:            %s\n' "$LOG_DIR"
}

require_adb() {
  [[ -x "$ADB_BIN" ]] || fail "ADB executable not found or not executable: $ADB_BIN"
}

adb_cmd() {
  require_adb

  if [[ -n "$ANDROID_SERIAL" ]]; then
    "$ADB_BIN" -s "$ANDROID_SERIAL" "$@"
    return
  fi

  "$ADB_BIN" "$@"
}

require_android_device() {
  if ! adb_cmd get-state >/dev/null 2>&1; then
    fail "ADB target not reachable: $ADB_TARGET_LABEL"
  fi
}

start_background_command() {
  local name=$1
  local repo=$2
  local command=$3
  local pid_file="$PID_DIR/$name.pid"
  local log_file="$LOG_DIR/$name.log"

  rm -f "$pid_file"

  (
    cd "$repo"
    exec bash -lc "$command"
  ) >"$log_file" 2>&1 &

  local pid=$!
  echo "$pid" > "$pid_file"
  printf 'Started %-16s pid=%-8s log=%s\n' "$name" "$pid" "$log_file"
}

stop_pid_file() {
  local pid_file=$1

  if [[ ! -f "$pid_file" ]]; then
    return 0
  fi

  local pid
  pid=$(cat "$pid_file")

  if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    sleep 1
    if kill -0 "$pid" 2>/dev/null; then
      kill -9 "$pid" 2>/dev/null || true
    fi
  fi

  rm -f "$pid_file"
}

kill_port_if_listening() {
  local port=$1
  local pids

  pids=$(lsof -tiTCP:"$port" -sTCP:LISTEN 2>/dev/null || true)
  if [[ -n "$pids" ]]; then
    printf '%s\n' "$pids" | xargs kill 2>/dev/null || true
  fi
}

http_check() {
  local label=$1
  local url=$2

  if curl -skf "$url" >/dev/null; then
    printf '[ok]   %s -> %s\n' "$label" "$url"
    return 0
  fi

  printf '[fail] %s -> %s\n' "$label" "$url"
  return 1
}
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
IOS_WALLET_REPO="${IOS_WALLET_REPO:-$CODE_ROOT/eudi-app-ios-wallet-ui}"
AUTH_REPO="${AUTH_REPO:-$CODE_ROOT/eudi-srv-issuer-oidc-py}"
ISSUER_REPO="${ISSUER_REPO:-$CODE_ROOT/eudi-srv-web-issuing-eudiw-py}"
FRONTEND_REPO="${FRONTEND_REPO:-$CODE_ROOT/eudi-srv-web-issuing-frontend-eudiw-py}"
VERIFIER_REPO="${VERIFIER_REPO:-$CODE_ROOT/av-srv-web-verifier-endpoint-23220-4-kt}"
VERIFIER_UI_REPO="${VERIFIER_UI_REPO:-$CODE_ROOT/eudi-web-verifier}"

IOS_PROJECT_FILE="${IOS_PROJECT_FILE:-$IOS_WALLET_REPO/EudiReferenceWallet.xcodeproj}"
IOS_SCHEME="${IOS_SCHEME:-EUDI Wallet Dev}"
IOS_CONFIGURATION="${IOS_CONFIGURATION:-Debug Dev}"
IOS_SIMULATOR_NAME="${IOS_SIMULATOR_NAME:-iPhone 16 Pro}"
IOS_DESTINATION="${IOS_DESTINATION:-platform=iOS Simulator,name=$IOS_SIMULATOR_NAME}"
IOS_PRODUCT_NAME="${IOS_PRODUCT_NAME:-EudiWallet.app}"
IOS_DERIVED_DATA_PATH="${IOS_DERIVED_DATA_PATH:-$IOS_WALLET_REPO/.build/DerivedData}"
IOS_SIMULATOR_APP_PATH="${IOS_SIMULATOR_APP_PATH:-$IOS_DERIVED_DATA_PATH/Build/Products/${IOS_CONFIGURATION}-iphonesimulator/$IOS_PRODUCT_NAME}"
IOS_DEVICE_APP_PATH="${IOS_DEVICE_APP_PATH:-$IOS_DERIVED_DATA_PATH/Build/Products/${IOS_CONFIGURATION}-iphoneos/$IOS_PRODUCT_NAME}"
IOS_USE_LOCAL_STACK="${IOS_USE_LOCAL_STACK:-true}"
IOS_LOCAL_ISSUER_URL="${IOS_LOCAL_ISSUER_URL:-}"
IOS_LOCAL_ISSUER_CLIENT_ID="${IOS_LOCAL_ISSUER_CLIENT_ID:-wallet-dev-local}"
IOS_LOCAL_WALLET_ATTESTATION_URL="${IOS_LOCAL_WALLET_ATTESTATION_URL:-}"
IOS_LOCAL_TRUSTED_HOSTS="${IOS_LOCAL_TRUSTED_HOSTS:-}"
IOS_LOCAL_VERIFIER_CLIENT_ID="${IOS_LOCAL_VERIFIER_CLIENT_ID:-Verifier}"
IOS_LOCAL_VERIFIER_URL="${IOS_LOCAL_VERIFIER_URL:-}"
IOS_INSTALL_LOCAL_ROOT_CERT="${IOS_INSTALL_LOCAL_ROOT_CERT:-true}"

detect_lan_ip() {
  ipconfig getifaddr en0 2>/dev/null || ipconfig getifaddr en1 2>/dev/null || true
}

current_developer_dir() {
  xcode-select -p 2>/dev/null || true
}

find_xcode_apps() {
  find /Applications "$HOME/Applications" -maxdepth 2 -name 'Xcode*.app' 2>/dev/null | sort -u
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
VERIFIER_TLS_HOST_PORT="${VERIFIER_TLS_HOST_PORT:-443}"

if [[ "$VERIFIER_TLS_HOST_PORT" == "443" ]]; then
  VERIFIER_PUBLIC_PORT_SUFFIX=""
else
  VERIFIER_PUBLIC_PORT_SUFFIX=":$VERIFIER_TLS_HOST_PORT"
fi

AUTH_URL="${AUTH_URL:-https://$PUBLIC_HOST:$AUTH_PORT}"
ISSUER_URL="${ISSUER_URL:-https://$PUBLIC_HOST:$ISSUER_PORT}"
FRONTEND_URL="${FRONTEND_URL:-https://$PUBLIC_HOST:$FRONTEND_PORT}"
VERIFIER_PUBLIC_URL="${VERIFIER_PUBLIC_URL:-https://$VERIFIER_PUBLIC_HOST$VERIFIER_PUBLIC_PORT_SUFFIX}"

case "$IOS_USE_LOCAL_STACK" in
  [Tt][Rr][Uu][Ee]|1|[Yy][Ee][Ss]|[Oo][Nn])
    if [[ -z "$IOS_LOCAL_ISSUER_URL" ]]; then
      IOS_LOCAL_ISSUER_URL="$FRONTEND_URL"
    fi

    if [[ -z "$IOS_LOCAL_WALLET_ATTESTATION_URL" ]]; then
      IOS_LOCAL_WALLET_ATTESTATION_URL="$AUTH_URL"
    fi

    if [[ -z "$IOS_LOCAL_VERIFIER_URL" ]]; then
      IOS_LOCAL_VERIFIER_URL="$VERIFIER_PUBLIC_URL"
    fi

    if [[ -z "$IOS_LOCAL_TRUSTED_HOSTS" ]]; then
      IOS_LOCAL_TRUSTED_HOSTS="$PUBLIC_HOST,localhost,127.0.0.1"
    fi
    ;;
esac

SHARED_CERT_FILE="${SHARED_CERT_FILE:-$ISSUER_REPO/local/runtime/runtime-ec.crt}"
SHARED_KEY_FILE="${SHARED_KEY_FILE:-$ISSUER_REPO/local/runtime/runtime-ec.key}"

ADB_BIN="${ADB_BIN:-$(detect_adb_bin)}"
ANDROID_SDK_DIR="${ANDROID_SDK_DIR:-$(detect_android_sdk_dir)}"
LOCAL_APK_PATH="${LOCAL_APK_PATH:-$WALLET_REPO/app/build/outputs/apk/dev/debug/app-dev-debug.apk}"
TEST_APK_PATH="${TEST_APK_PATH:-$WALLET_REPO/app/build/outputs/apk/demo/debug/app-demo-debug.apk}"
APK_PATH="${APK_PATH:-$LOCAL_APK_PATH}"
ANDROID_SERIAL="${ANDROID_SERIAL:-}"

case "$ANDROID_SERIAL" in
  "''"|'""') ANDROID_SERIAL="" ;;
esac

ADB_TARGET_LABEL="${ANDROID_SERIAL:-default adb target}"

if [[ -z "${IOS_BUNDLE_ID:-}" ]]; then
  case "$IOS_SCHEME" in
    *Demo*) IOS_BUNDLE_ID="eu.europa.ec.euidi" ;;
    *) IOS_BUNDLE_ID="eu.europa.ec.euidi.dev" ;;
  esac
fi

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

print_xcode_status() {
  local developer_dir
  local xcode_apps

  developer_dir="$(current_developer_dir)"
  xcode_apps="$(find_xcode_apps || true)"

  section "Xcode Status"
  printf 'Active developer dir: %s\n' "${developer_dir:-unavailable}"
  if [[ -n "$xcode_apps" ]]; then
    printf 'Installed Xcode apps:\n%s\n' "$xcode_apps"
  else
    printf 'Installed Xcode apps: none found under /Applications or ~/Applications\n'
  fi
}

require_full_xcode() {
  require_command xcode-select

  local developer_dir
  developer_dir="$(current_developer_dir)"

  if [[ -z "$developer_dir" || "$developer_dir" == "/Library/Developer/CommandLineTools" ]]; then
    print_xcode_status
    fail "Full Xcode is not selected. Install Xcode and switch the active developer directory before running iOS scripts."
  fi

  if ! xcodebuild -version >/dev/null 2>&1; then
    print_xcode_status
    fail "xcodebuild is unavailable from the active developer directory."
  fi
}

ios_should_use_local_stack() {
  case "$IOS_USE_LOCAL_STACK" in
    [Tt][Rr][Uu][Ee]|1|[Yy][Ee][Ss]|[Oo][Nn])
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

ios_local_endpoints_enabled() {
  [[ -n "$IOS_LOCAL_ISSUER_URL" || -n "$IOS_LOCAL_WALLET_ATTESTATION_URL" || -n "$IOS_LOCAL_VERIFIER_URL" ]]
}

ios_should_install_local_root_cert() {
  case "$IOS_INSTALL_LOCAL_ROOT_CERT" in
    [Tt][Rr][Uu][Ee]|1|[Yy][Ee][Ss]|[Oo][Nn])
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

install_ios_simulator_root_cert() {
  local simulator_udid=$1

  ios_local_endpoints_enabled || return 0
  ios_should_install_local_root_cert || return 0

  require_file "$SHARED_CERT_FILE"

  xcrun simctl keychain "$simulator_udid" add-root-cert "$SHARED_CERT_FILE"
  printf '[ok]   simulator trusts local root cert -> %s\n' "$SHARED_CERT_FILE"
}

resolve_ios_simulator() {
  local line
  local matched_line=""
  local fallback_line=""

  while IFS= read -r line; do
    [[ "$line" == *"("*")"* ]] || continue

    if [[ "$line" == *"$IOS_SIMULATOR_NAME"* ]]; then
      matched_line="$line"
      break
    fi

    if [[ -z "$fallback_line" && "$line" == *"iPhone"* ]]; then
      fallback_line="$line"
    fi
  done < <(xcrun simctl list devices available)

  if [[ -z "$matched_line" ]]; then
    matched_line="$fallback_line"
  fi

  if [[ -z "$matched_line" ]]; then
    return 1
  fi

  IOS_RESOLVED_SIMULATOR_UDID="$(printf '%s\n' "$matched_line" | sed -E 's/.*\(([0-9A-F-]+)\).*/\1/')"
  IOS_RESOLVED_SIMULATOR_NAME="$(printf '%s\n' "$matched_line" | sed -E 's/^ *//; s/ \([0-9A-F-]+\).*//')"
  IOS_RESOLVED_DESTINATION="platform=iOS Simulator,id=$IOS_RESOLVED_SIMULATOR_UDID"
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

sync_wallet_local_demo_host() {
  sync_wallet_local_properties
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

print_ios_runtime_summary() {
  section "iOS Wallet Summary"
  printf 'iOS repo:           %s\n' "$IOS_WALLET_REPO"
  printf 'Project:            %s\n' "$IOS_PROJECT_FILE"
  printf 'Scheme:             %s\n' "$IOS_SCHEME"
  printf 'Configuration:      %s\n' "$IOS_CONFIGURATION"
  printf 'Local stack mode:   %s\n' "$IOS_USE_LOCAL_STACK"
  printf 'Requested sim:      %s\n' "$IOS_SIMULATOR_NAME"
  printf 'Resolved sim:       %s\n' "${IOS_RESOLVED_SIMULATOR_NAME:-pending resolution}"
  printf 'Destination:        %s\n' "${IOS_RESOLVED_DESTINATION:-$IOS_DESTINATION}"
  printf 'Bundle ID:          %s\n' "$IOS_BUNDLE_ID"
  printf 'DerivedData:        %s\n' "$IOS_DERIVED_DATA_PATH"
  printf 'Simulator app:      %s\n' "$IOS_SIMULATOR_APP_PATH"
  printf 'Device app:         %s\n' "$IOS_DEVICE_APP_PATH"
  printf 'Local issuer URL:   %s\n' "${IOS_LOCAL_ISSUER_URL:-disabled}"
  printf 'Local attestation:  %s\n' "${IOS_LOCAL_WALLET_ATTESTATION_URL:-disabled}"
  printf 'Local verifier URL: %s\n' "${IOS_LOCAL_VERIFIER_URL:-disabled}"
  printf 'Local verifier id:  %s\n' "${IOS_LOCAL_VERIFIER_CLIENT_ID:-disabled}"
  printf 'Local trusted TLS:  %s\n' "${IOS_LOCAL_TRUSTED_HOSTS:-derived from override URLs only}"
  printf 'Local root cert:    %s\n' "${IOS_INSTALL_LOCAL_ROOT_CERT:-true}"
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

cert_sha256_fingerprint_from_file() {
  local cert_file=$1

  [[ -f "$cert_file" ]] || return 1

  openssl x509 -in "$cert_file" -noout -fingerprint -sha256 2>/dev/null | sed 's/^.*=//'
}

tls_sha256_fingerprint_from_url() {
  local url=$1
  local authority=${url#*://}
  authority=${authority%%/*}

  local host=${authority%%:*}
  local port=443

  if [[ "$authority" == *:* ]]; then
    port=${authority##*:}
  fi

  openssl s_client -connect "${host}:${port}" -servername "$host" </dev/null 2>/dev/null | \
    openssl x509 -noout -fingerprint -sha256 2>/dev/null | sed 's/^.*=//'
}

tls_cert_matches_shared_cert() {
  local label=$1
  local url=$2
  local expected_fingerprint
  local live_fingerprint

  expected_fingerprint=$(cert_sha256_fingerprint_from_file "$SHARED_CERT_FILE") || {
    printf '[fail] %s TLS cert check -> missing shared cert %s\n' "$label" "$SHARED_CERT_FILE"
    return 1
  }

  live_fingerprint=$(tls_sha256_fingerprint_from_url "$url")
  if [[ -z "$live_fingerprint" ]]; then
    printf '[fail] %s TLS cert check -> unable to read live certificate from %s\n' "$label" "$url"
    return 1
  fi

  if [[ "$live_fingerprint" == "$expected_fingerprint" ]]; then
    printf '[ok]   %s TLS cert matches shared cert -> %s\n' "$label" "$url"
    return 0
  fi

  printf '[fail] %s TLS cert mismatch -> %s\n' "$label" "$url"
  printf '       expected: %s\n' "$expected_fingerprint"
  printf '       live:     %s\n' "$live_fingerprint"
  printf '       shared:   %s\n' "$SHARED_CERT_FILE"
  return 1
}

read_plist_value() {
  local plist_file=$1
  local key=$2

  /usr/libexec/PlistBuddy -c "Print :'$key'" "$plist_file" 2>/dev/null || true
}

assert_ios_compiled_bundle_value() {
  local label=$1
  local key=$2
  local expected=$3
  local failure_hint=$4
  local plist_file="$IOS_SIMULATOR_APP_PATH/Info.plist"
  local actual

  require_file "$plist_file"
  actual="$(read_plist_value "$plist_file" "$key")"

  if [[ "$actual" == "$expected" ]]; then
    printf '[ok]   %s compiled -> %s\n' "$label" "$actual"
    return 0
  fi

  printf '[fail] %s compiled mismatch\n' "$label"
  printf '       expected: %s\n' "$expected"
  printf '       actual:   %s\n' "${actual:-<empty>}"
  printf '       hint:     %s\n' "$failure_hint"
  return 1
}

assert_ios_local_bundle_configuration() {
  ios_should_use_local_stack || return 0

  local failures=0

  assert_ios_compiled_bundle_value \
    "Local issuer URL" \
    "Local Issuer Url" \
    "$IOS_LOCAL_ISSUER_URL" \
    "Without the local issuer override, the simulator wallet will not offer the local credential types." || failures=$((failures + 1))

  assert_ios_compiled_bundle_value \
    "Local issuer client id" \
    "Local Issuer Client Id" \
    "$IOS_LOCAL_ISSUER_CLIENT_ID" \
    "Keep the local issuer client id aligned with the auth stack used by the local issuer frontend." || failures=$((failures + 1))

  assert_ios_compiled_bundle_value \
    "Local attestation URL" \
    "Local Wallet Attestation Url" \
    "$IOS_LOCAL_WALLET_ATTESTATION_URL" \
    "Browser-based issuance needs the wallet attestation override compiled into the simulator build." || failures=$((failures + 1))

  assert_ios_compiled_bundle_value \
    "Local verifier URL" \
    "Local Verifier Url" \
    "$IOS_LOCAL_VERIFIER_URL" \
    "Same-device verification needs preregistered verifier metadata compiled into the simulator build." || failures=$((failures + 1))

  assert_ios_compiled_bundle_value \
    "Local verifier client id" \
    "Local Verifier Client Id" \
    "$IOS_LOCAL_VERIFIER_CLIENT_ID" \
    "Keep the simulator build aligned with the verifier backend preregistered client id." || failures=$((failures + 1))

  if [[ $failures -ne 0 ]]; then
    return 1
  fi
}
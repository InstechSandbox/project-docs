#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

failures=0

section "HTTP Smoke Checks"
http_check "Auth discovery" "$AUTH_URL/.well-known/openid-configuration" || failures=$((failures + 1))
http_check "Auth AS metadata" "$AUTH_URL/.well-known/oauth-authorization-server" || failures=$((failures + 1))
http_check "Issuer metadata" "$ISSUER_URL/.well-known/openid-credential-issuer" || failures=$((failures + 1))
http_check "Frontend root" "$FRONTEND_URL/" || failures=$((failures + 1))
http_check "Verifier public" "$VERIFIER_PUBLIC_URL/" || failures=$((failures + 1))

section "TLS Certificate Alignment"
tls_cert_matches_shared_cert "Auth server" "$AUTH_URL" || failures=$((failures + 1))
tls_cert_matches_shared_cert "Issuer backend" "$ISSUER_URL" || failures=$((failures + 1))
tls_cert_matches_shared_cert "Issuer frontend" "$FRONTEND_URL" || failures=$((failures + 1))

section "Docker Status"
(
  cd "$VERIFIER_REPO"
  docker compose -f docker/docker-compose.local.yml ps
) || failures=$((failures + 1))

section "Wallet Artifact"
if [[ -f "$APK_PATH" ]]; then
  ls -lh "$APK_PATH"
else
  printf '[fail] APK not found: %s\n' "$APK_PATH"
  failures=$((failures + 1))
fi

section "ADB Status"
if [[ -x "$ADB_BIN" ]]; then
  "$ADB_BIN" devices -l || failures=$((failures + 1))

  require_android_in_smoke="${SMOKE_REQUIRE_ANDROID_DEVICE:-false}"

  if [[ -n "$ANDROID_SERIAL" ]]; then
    if adb_cmd get-state >/dev/null 2>&1; then
      printf '[ok]   adb target -> %s\n' "$ADB_TARGET_LABEL"
    else
      case "$require_android_in_smoke" in
        [Tt][Rr][Uu][Ee]|1|[Yy][Ee][Ss]|[Oo][Nn])
          printf '[fail] adb target -> %s\n' "$ADB_TARGET_LABEL"
          failures=$((failures + 1))
          ;;
        *)
          printf '[warn] adb target unavailable -> %s\n' "$ADB_TARGET_LABEL"
          printf '       Set SMOKE_REQUIRE_ANDROID_DEVICE=true if device reachability should fail the smoke run.\n'
          ;;
      esac
    fi
  fi
else
  printf 'ADB not found at %s\n' "$ADB_BIN"
  failures=$((failures + 1))
fi

section "Result"
if [[ "$failures" -eq 0 ]]; then
  printf 'All smoke checks passed.\n'
  exit 0
fi

printf '%s smoke check(s) failed.\n' "$failures"
exit 1
#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

section "Preflight"
require_dir "$IOS_WALLET_REPO"
require_dir "$IOS_PROJECT_FILE"
require_dir "$IOS_SIMULATOR_APP_PATH"
require_command bash
require_command xcrun
require_full_xcode

if ! resolve_ios_simulator; then
  fail "No available iOS simulator found with name: $IOS_SIMULATOR_NAME"
fi

section "Simulator Boot"
open -a Simulator >/dev/null 2>&1 || true
xcrun simctl boot "$IOS_RESOLVED_SIMULATOR_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$IOS_RESOLVED_SIMULATOR_UDID" -b
printf '[ok]   simulator booted -> %s (%s)\n' "$IOS_RESOLVED_SIMULATOR_NAME" "$IOS_RESOLVED_SIMULATOR_UDID"

section "Simulator Trust"
if ios_local_endpoints_enabled; then
  tls_cert_matches_shared_cert "Local attestation endpoint" "${IOS_LOCAL_WALLET_ATTESTATION_URL:-$AUTH_URL}"
  tls_cert_matches_shared_cert "Local issuer endpoint" "${IOS_LOCAL_ISSUER_URL:-$FRONTEND_URL}"
  tls_cert_matches_shared_cert "Local verifier endpoint" "${IOS_LOCAL_VERIFIER_URL:-$VERIFIER_PUBLIC_URL}"
fi

install_ios_simulator_root_cert "$IOS_RESOLVED_SIMULATOR_UDID"

section "App Install"
xcrun simctl install "$IOS_RESOLVED_SIMULATOR_UDID" "$IOS_SIMULATOR_APP_PATH"
printf '[ok]   installed app -> %s\n' "$IOS_SIMULATOR_APP_PATH"

section "Compiled App Config"
assert_ios_local_bundle_configuration

section "App Launch"
LAUNCH_OUTPUT="$(xcrun simctl launch "$IOS_RESOLVED_SIMULATOR_UDID" "$IOS_BUNDLE_ID")"
printf '[ok]   launch output -> %s\n' "$LAUNCH_OUTPUT"

print_ios_runtime_summary

section "Smoke Complete"
printf 'iOS simulator smoke checks passed.\n'
#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

section "Preflight"
require_file "$VERIFIER_REPO/scripts/generate-verifier-deeplink.sh"
require_command bash
require_command xcrun
require_full_xcode

if ! resolve_ios_simulator; then
  fail "No available iOS simulator found with name: $IOS_SIMULATOR_NAME"
fi

section "Prepare Simulator"
open -a Simulator >/dev/null 2>&1 || true
xcrun simctl boot "$IOS_RESOLVED_SIMULATOR_UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$IOS_RESOLVED_SIMULATOR_UDID" -b
printf '[ok]   simulator booted -> %s (%s)\n' "$IOS_RESOLVED_SIMULATOR_NAME" "$IOS_RESOLVED_SIMULATOR_UDID"

section "Generate Verification Deep Link"
parsed=$(VERIFIER_PUBLIC_HOST="$VERIFIER_PUBLIC_HOST" VERIFIER_PUBLIC_URL="$VERIFIER_PUBLIC_URL" "$VERIFIER_REPO/scripts/generate-verifier-deeplink.sh")
printf '%s\n' "$parsed"

deeplink=$(printf '%s\n' "$parsed" | awk -F= '/^deeplink=/{print substr($0,10)}')
[[ -n "$deeplink" ]] || fail "Failed to derive verifier deeplink"

case "$deeplink" in
  *"response_type=vp_token"*)
    printf '[ok]   deeplink contains response_type=vp_token\n'
    ;;
  *)
    fail "Verifier deeplink is missing response_type=vp_token: $deeplink"
    ;;
esac

section "Open Deep Link"
xcrun simctl openurl "$IOS_RESOLVED_SIMULATOR_UDID" "$deeplink"
printf '[ok]   opened verifier deeplink in simulator\n'

section "Done"
printf 'If the wallet opens but still shows no proof request, inspect verifier backend logs for /wallet/request.jwt activity.\n'
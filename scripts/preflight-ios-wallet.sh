#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

section "Preflight"
require_dir "$IOS_WALLET_REPO"
require_dir "$IOS_PROJECT_FILE"
require_command bash
require_command xcrun
require_full_xcode

section "Project Metadata"
xcodebuild -list -project "$IOS_PROJECT_FILE" >/dev/null
printf '[ok]   iOS project  %s\n' "$IOS_PROJECT_FILE"
printf '[ok]   scheme       %s\n' "$IOS_SCHEME"
printf '[ok]   config       %s\n' "$IOS_CONFIGURATION"

section "Simulator Availability"
if ! resolve_ios_simulator; then
  fail "No available iOS simulator found with name: $IOS_SIMULATOR_NAME"
fi

printf '[ok]   simulator    %s (%s)\n' "$IOS_RESOLVED_SIMULATOR_NAME" "$IOS_RESOLVED_SIMULATOR_UDID"
print_ios_runtime_summary

section "Preflight Complete"
printf 'Next step: %s/build-ios-wallet-simulator.sh\n' "$SCRIPT_DIR"
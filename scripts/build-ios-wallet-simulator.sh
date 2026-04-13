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

if ! resolve_ios_simulator; then
  fail "No available iOS simulator found with name: $IOS_SIMULATOR_NAME"
fi

section "iOS Simulator Build"
rm -rf "$IOS_DERIVED_DATA_PATH"

XCODEBUILD_SETTINGS=()

if [[ -n "$IOS_LOCAL_ISSUER_URL" ]]; then
  XCODEBUILD_SETTINGS+=("LOCAL_ISSUER_URL=$IOS_LOCAL_ISSUER_URL")
  XCODEBUILD_SETTINGS+=("LOCAL_ISSUER_CLIENT_ID=$IOS_LOCAL_ISSUER_CLIENT_ID")
fi

if [[ -n "$IOS_LOCAL_WALLET_ATTESTATION_URL" ]]; then
  XCODEBUILD_SETTINGS+=("LOCAL_WALLET_ATTESTATION_URL=$IOS_LOCAL_WALLET_ATTESTATION_URL")
fi

if [[ -n "$IOS_LOCAL_TRUSTED_HOSTS" ]]; then
  XCODEBUILD_SETTINGS+=("LOCAL_TRUSTED_HOSTS=$IOS_LOCAL_TRUSTED_HOSTS")
fi

if [[ -n "$IOS_LOCAL_VERIFIER_URL" ]]; then
  XCODEBUILD_SETTINGS+=("LOCAL_VERIFIER_URL=$IOS_LOCAL_VERIFIER_URL")
  XCODEBUILD_SETTINGS+=("LOCAL_VERIFIER_CLIENT_ID=$IOS_LOCAL_VERIFIER_CLIENT_ID")
fi

(
  cd "$IOS_WALLET_REPO"

  XCODEBUILD_COMMAND=(
    xcodebuild
    -project "$IOS_PROJECT_FILE"
    -scheme "$IOS_SCHEME"
    -configuration "$IOS_CONFIGURATION"
    -destination "$IOS_RESOLVED_DESTINATION"
    -derivedDataPath "$IOS_DERIVED_DATA_PATH"
    -skipPackagePluginValidation
    -skipMacroValidation
    CODE_SIGNING_ALLOWED=NO
  )

  if [[ ${#XCODEBUILD_SETTINGS[@]} -gt 0 ]]; then
    XCODEBUILD_COMMAND+=("${XCODEBUILD_SETTINGS[@]}")
  fi

  XCODEBUILD_COMMAND+=(build)
  "${XCODEBUILD_COMMAND[@]}"
)

require_dir "$IOS_SIMULATOR_APP_PATH"
ls -lh "$IOS_SIMULATOR_APP_PATH"
print_ios_runtime_summary

section "Build Complete"
printf 'Next step: %s/smoke-ios-wallet-simulator.sh\n' "$SCRIPT_DIR"
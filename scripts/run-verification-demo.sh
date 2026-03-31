#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

section "Preflight"
require_android_device
require_file "$VERIFIER_REPO/scripts/generate-verifier-deeplink.sh"

section "Prepare Device"
adb_cmd shell am force-stop eu.europa.ec.euidi.dev >/dev/null 2>&1 || true
adb_cmd shell am force-stop eu.europa.ec.euidi >/dev/null 2>&1 || true

section "Run Verification Deep Link"
ADB_BIN="$ADB_BIN" \
ANDROID_SERIAL="$ANDROID_SERIAL" \
VERIFIER_PUBLIC_HOST="$VERIFIER_PUBLIC_HOST" \
VERIFIER_PUBLIC_URL="$VERIFIER_PUBLIC_URL" \
"$VERIFIER_REPO/scripts/generate-verifier-deeplink.sh" --run
#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

section "Preflight"
require_android_device
require_file "$ISSUER_REPO/scripts/generate-issuance-deeplink.sh"

section "Prepare Device"
adb_cmd shell am force-stop eu.europa.ec.euidi.dev >/dev/null 2>&1 || true
adb_cmd shell am force-stop eu.europa.ec.euidi >/dev/null 2>&1 || true

section "Run Issuance Deep Link"
if [[ -n "$ANDROID_SERIAL" ]]; then
	ADB_BIN="$ADB_BIN" \
	ANDROID_SERIAL="$ANDROID_SERIAL" \
	ISSUER_BACKEND_URL="$ISSUER_URL" \
	"$ISSUER_REPO/scripts/generate-issuance-deeplink.sh" --run
else
	ADB_BIN="$ADB_BIN" \
	ISSUER_BACKEND_URL="$ISSUER_URL" \
	"$ISSUER_REPO/scripts/generate-issuance-deeplink.sh" --run
fi
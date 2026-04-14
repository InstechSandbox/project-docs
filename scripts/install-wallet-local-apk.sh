#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

fresh_install=false

if [[ "${1:-}" == "--fresh" ]]; then
	fresh_install=true
fi

metadata_path="$(dirname "$APK_PATH")/output-metadata.json"
fallback_application_id="eu.europa.ec.euidi.dev"

apk_application_id=""
if [[ -f "$metadata_path" ]]; then
	apk_application_id=$(python3 - <<'PY' "$metadata_path"
import json
import sys

with open(sys.argv[1], 'r', encoding='utf-8') as handle:
		metadata = json.load(handle)

print(metadata.get('applicationId', ''))
PY
)
fi

if [[ -z "$apk_application_id" ]]; then
	apk_application_id="$fallback_application_id"
fi

section "Preflight"
require_android_device
"$SCRIPT_DIR/refresh-local-certs.sh" --sync-wallet-cert
sync_wallet_local_properties

section "Device"
printf 'Installing to adb target: %s\n' "$ADB_TARGET_LABEL"
printf 'APK applicationId: %s\n' "$apk_application_id"

if [[ "$fresh_install" == true ]]; then
	section "Fresh Install"
	if adb_cmd shell pm path "$apk_application_id" >/dev/null 2>&1; then
		printf 'Uninstalling existing package: %s\n' "$apk_application_id"
		adb_cmd uninstall "$apk_application_id"
	else
		printf 'No existing package to uninstall for %s\n' "$apk_application_id"
	fi
fi

section "Install Wallet"
(
	cd "$WALLET_REPO"
	LOCAL_DEMO_HOST="$PUBLIC_HOST" ./gradlew buildAndInstallDevDebug --console=plain
)

require_file "$APK_PATH"

section "Install Complete"
printf 'Installed local APK: %s\n' "$APK_PATH"
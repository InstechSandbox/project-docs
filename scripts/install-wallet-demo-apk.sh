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

section "Preflight"
require_file "$APK_PATH"
require_android_device

section "Device"
printf 'Installing to adb target: %s\n' "$ADB_TARGET_LABEL"
if [[ -n "$apk_application_id" ]]; then
	printf 'APK applicationId: %s\n' "$apk_application_id"
fi

if [[ "$fresh_install" == true && -z "$apk_application_id" ]]; then
	fail "Cannot perform --fresh install without APK metadata: $metadata_path"
fi

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
if output=$(adb_cmd install --no-streaming -r -d "$APK_PATH" 2>&1); then
	printf '%s\n' "$output"
else
	printf '%s\n' "$output" >&2
	if [[ "$output" == *"INSTALL_FAILED_VERSION_DOWNGRADE"* ]] && [[ -n "$apk_application_id" ]]; then
		printf '\nDetected higher-version package already installed for %s.\n' "$apk_application_id" >&2
		printf 'Retry with: %s --fresh\n' "$0" >&2
	fi
	exit 1
fi

section "Install Complete"
printf 'Installed APK: %s\n' "$APK_PATH"
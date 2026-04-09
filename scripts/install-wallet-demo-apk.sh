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
wallet_build_config="$WALLET_REPO/core-logic/build/generated/source/buildConfig/demo/debug/eu/europa/ec/corelogic/BuildConfig.java"
wallet_cert_file="$WALLET_REPO/network-logic/src/main/res/raw/backend_cert.pem"

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
sync_wallet_local_demo_host

if [[ -f "$wallet_cert_file" ]] && [[ -f "$SHARED_CERT_FILE" ]] && ! cmp -s "$wallet_cert_file" "$SHARED_CERT_FILE"; then
	fail "Wallet embedded PEM does not match the current shared local certificate. Run $SCRIPT_DIR/refresh-local-certs.sh --sync-wallet-cert and rebuild the wallet APK before installing."
fi

if [[ -f "$wallet_build_config" ]]; then
	built_verifier_api=$(awk -F'"' '/LOCAL_VERIFIER_API/ { print $2; exit }' "$wallet_build_config")
	expected_verifier_api="https://$PUBLIC_HOST"
	if [[ -n "$built_verifier_api" && "$built_verifier_api" != "$expected_verifier_api" ]]; then
		fail "Wallet APK was built for $built_verifier_api but current verifier host is $expected_verifier_api. Rebuild with (cd $WALLET_REPO && ./gradlew buildAndInstallDemoDebug --console=plain) or rerun project-docs/scripts/build-local-all.sh."
	fi
fi

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
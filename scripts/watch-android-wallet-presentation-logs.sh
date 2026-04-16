#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

section "Preflight"
require_android_device

if [[ "${1:-}" == "--clear" ]]; then
  info "Clearing existing logcat buffer"
  adb_cmd logcat -c
  shift
fi

section "Monitor Android Wallet Presentation Logs"
printf 'ADB target: %s\n' "$ADB_TARGET_LABEL"
printf 'Tags: WalletCorePresentationController, PresentationRequestInteractor\n'
printf 'Press Ctrl+C to stop.\n\n'

adb_cmd logcat -v time WalletCorePresentationController:I PresentationRequestInteractor:I '*:S'
#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
printf 'install-wallet-demo-apk.sh is now a compatibility alias for the local DEV wallet install path.\n' >&2
exec "$SCRIPT_DIR/install-wallet-local-apk.sh" "$@"
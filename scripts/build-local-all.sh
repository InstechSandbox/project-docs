#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

section "Preflight"
require_dir "$WALLET_REPO"
require_dir "$AUTH_REPO"
require_dir "$ISSUER_REPO"
require_dir "$FRONTEND_REPO"
require_dir "$VERIFIER_REPO"
require_dir "$VERIFIER_UI_REPO"
require_command docker
require_command bash

section "Python Service Preflight"
require_file "$AUTH_REPO/.venv/bin/python"
require_file "$ISSUER_REPO/.venv/bin/flask"
require_file "$FRONTEND_REPO/.venv/bin/flask"
printf '[ok]   auth venv    %s\n' "$AUTH_REPO/.venv/bin/python"
printf '[ok]   issuer venv  %s\n' "$ISSUER_REPO/.venv/bin/flask"
printf '[ok]   frontend venv %s\n' "$FRONTEND_REPO/.venv/bin/flask"

"$SCRIPT_DIR/refresh-local-certs.sh"
sync_wallet_local_demo_host

section "Wallet APK Build"
(
  cd "$WALLET_REPO"
  LOCAL_DEMO_HOST="$PUBLIC_HOST" ./gradlew :app:assembleDemoDebug -x clean --console=plain
)

require_file "$APK_PATH"
ls -lh "$APK_PATH"

section "Verifier Docker Build"
(
  cd "$VERIFIER_REPO"
  docker compose -f docker/docker-compose.local.yml build
)

print_runtime_summary

section "Build Complete"
printf 'Fresh demo APK: %s\n' "$APK_PATH"
printf 'Next step:      %s/start-local-all.sh\n' "$SCRIPT_DIR"
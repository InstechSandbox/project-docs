#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

section "Preflight"
require_file "$SCRIPT_DIR/refresh-local-certs.sh"
require_file "$AUTH_REPO/.venv/bin/python"
require_file "$AUTH_REPO/patch_auth_server_local.sh"
require_file "$ISSUER_REPO/.venv/bin/flask"
require_file "$FRONTEND_REPO/.venv/bin/flask"
require_file "$VERIFIER_REPO/scripts/start-local-verifier.sh"

"$SCRIPT_DIR/refresh-local-certs.sh"

require_file "$SHARED_CERT_FILE"
require_file "$SHARED_KEY_FILE"

section "Stopping Any Existing Local Stack"
"$SCRIPT_DIR/stop-local-all.sh" --quiet

section "Starting Python Services"
start_background_command \
  auth-server \
  "$AUTH_REPO" \
  "source .venv/bin/activate && MYIP='$PUBLIC_HOST' AUTH_PORT='$AUTH_PORT' ISSUER_PORT='$ISSUER_PORT' ./patch_auth_server_local.sh && exec .venv/bin/python server.py config.json --cert '$SHARED_CERT_FILE' --key '$SHARED_KEY_FILE'"

start_background_command \
  issuer-backend \
  "$ISSUER_REPO" \
  "source .venv/bin/activate && MYIP='$PUBLIC_HOST' AUTH_PORT='$AUTH_PORT' ISSUER_PORT='$ISSUER_PORT' FRONTEND_PORT='$FRONTEND_PORT' ./patch_issuer_backend_local.sh && ISSUER_CERT_FILE='$SHARED_CERT_FILE' ISSUER_KEY_FILE='$SHARED_KEY_FILE' exec ./run_backend.sh"

start_background_command \
  issuer-frontend \
  "$FRONTEND_REPO" \
  "source .venv/bin/activate && MYIP='$PUBLIC_HOST' BACKEND_HOST='$PUBLIC_HOST' BACKEND_PORT='$AUTH_PORT' BACKEND_CERT_SOURCE='$SHARED_CERT_FILE' AUTH_PORT='$AUTH_PORT' ISSUER_PORT='$ISSUER_PORT' FRONTEND_PORT='$FRONTEND_PORT' FRONTEND_CERT_FILE='$SHARED_CERT_FILE' FRONTEND_KEY_FILE='$SHARED_KEY_FILE' exec ./run_frontend.sh"

section "Starting Docker Verifier Stack"
(
  cd "$VERIFIER_REPO"
  VERIFIER_PUBLIC_HOST="$VERIFIER_PUBLIC_HOST" \
  VERIFIER_SHARED_CERT_FILE="$SHARED_CERT_FILE" \
  VERIFIER_SHARED_KEY_FILE="$SHARED_KEY_FILE" \
  ./scripts/start-local-verifier.sh
)

print_runtime_summary

section "Startup Grace Period"
sleep 5

section "Startup Hint"
printf 'Run %s/smoke-local-all.sh to verify the stack before recording.\n' "$SCRIPT_DIR"
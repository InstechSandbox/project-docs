#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

section "Preflight"
require_file "$SCRIPT_DIR/refresh-local-certs.sh"
require_file "$AUTH_REPO/patch_auth_server_local.sh"
require_supported_venv_python "auth venv" "$AUTH_REPO/.venv/bin/python"
require_supported_venv_python "issuer venv" "$ISSUER_REPO/.venv/bin/python"
require_supported_venv_python "frontend venv" "$FRONTEND_REPO/.venv/bin/python"
require_file "$FRONTEND_REPO/.venv/bin/flask"
require_file "$VERIFIER_REPO/scripts/start-local-verifier.sh"

"$SCRIPT_DIR/refresh-local-certs.sh"

require_file "$SHARED_CERT_FILE"
require_file "$SHARED_KEY_FILE"

AUTH_RUNTIME_DIR="$LOCAL_STATE_DIR/auth-server"
ISSUER_RUNTIME_DIR="$LOCAL_STATE_DIR/issuer-backend"
mkdir -p "$AUTH_RUNTIME_DIR" "$ISSUER_RUNTIME_DIR"

section "Stopping Any Existing Local Stack"
"$SCRIPT_DIR/stop-local-all.sh" --quiet

section "Starting Python Services"
start_background_command \
  auth-server \
  "$AUTH_REPO" \
  "source .venv/bin/activate && MYIP='$PUBLIC_HOST' AUTH_PORT='$AUTH_PORT' ISSUER_PORT='$ISSUER_PORT' LOCAL_RUNTIME_DIR='$AUTH_RUNTIME_DIR' AUTH_CONFIG_FILE='$AUTH_RUNTIME_DIR/config.json' AUTH_OPENID_CONFIGURATION_FILE='$AUTH_RUNTIME_DIR/openid-configuration.json' AUTH_SERVER_CERT_FILE='$SHARED_CERT_FILE' AUTH_SERVER_KEY_FILE='$SHARED_KEY_FILE' SHARED_CERT_FILE='$SHARED_CERT_FILE' SHARED_KEY_FILE='$SHARED_KEY_FILE' ./patch_auth_server_local.sh && AUTH_OPENID_CONFIGURATION_FILE='$AUTH_RUNTIME_DIR/openid-configuration.json' exec .venv/bin/python server.py '$AUTH_RUNTIME_DIR/config.json' --cert '$SHARED_CERT_FILE' --key '$SHARED_KEY_FILE'"

start_background_command \
  issuer-backend \
  "$ISSUER_REPO" \
  "source .venv/bin/activate && MYIP='$PUBLIC_HOST' AUTH_PORT='$AUTH_PORT' ISSUER_PORT='$ISSUER_PORT' FRONTEND_PORT='$FRONTEND_PORT' LOCAL_RUNTIME_DIR='$ISSUER_RUNTIME_DIR' ISSUER_METADATA_OVERRIDES_FILE='$ISSUER_RUNTIME_DIR/metadata_overrides.json' ./patch_issuer_backend_local.sh && MYIP='$PUBLIC_HOST' AUTH_PORT='$AUTH_PORT' ISSUER_PORT='$ISSUER_PORT' FRONTEND_PORT='$FRONTEND_PORT' ISSUER_METADATA_OVERRIDES_FILE='$ISSUER_RUNTIME_DIR/metadata_overrides.json' ISSUER_CERT_FILE='$SHARED_CERT_FILE' ISSUER_KEY_FILE='$SHARED_KEY_FILE' exec ./run_backend.sh"

start_background_command \
  issuer-frontend \
  "$FRONTEND_REPO" \
  "source .venv/bin/activate && MYIP='$PUBLIC_HOST' BACKEND_HOST='$PUBLIC_HOST' BACKEND_PORT='$AUTH_PORT' BACKEND_CERT_SOURCE='$SHARED_CERT_FILE' AUTH_PORT='$AUTH_PORT' ISSUER_PORT='$ISSUER_PORT' FRONTEND_PORT='$FRONTEND_PORT' ISSUER_URL='$ISSUER_URL' CREDENTIALS_SUPPORTED='eu.europa.ec.eudi.pid_mdoc,eu.europa.ec.eudi.pid_vc_sd_jwt,eu.europa.ec.eudi.mdl_mdoc' FRONTEND_CERT_FILE='$SHARED_CERT_FILE' FRONTEND_KEY_FILE='$SHARED_KEY_FILE' exec ./run_frontend.sh"

section "Starting Docker Verifier Stack"
(
  cd "$VERIFIER_REPO"
    COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-}" \
    VERIFIER_STACK_SUFFIX="${VERIFIER_STACK_SUFFIX:-}" \
  VERIFIER_PUBLIC_HOST="$VERIFIER_PUBLIC_HOST" \
  VERIFIER_PUBLIC_URL="$VERIFIER_PUBLIC_URL" \
  VERIFIER_IRISHLIFE_CUSTOMERBASEURL="$VERIFIER_PUBLIC_URL" \
    VERIFIER_TLS_HOST_PORT="$VERIFIER_TLS_HOST_PORT" \
    VERIFIER_BACKEND_HOST_PORT="$VERIFIER_BACKEND_HOST_PORT" \
    VERIFIER_UI_HOST_PORT="$VERIFIER_UI_HOST_PORT" \
    VERIFIER_BACKEND_CONTAINER_NAME="$VERIFIER_BACKEND_CONTAINER_NAME" \
    VERIFIER_UI_CONTAINER_NAME="$VERIFIER_UI_CONTAINER_NAME" \
    VERIFIER_HAPROXY_CONTAINER_NAME="$VERIFIER_HAPROXY_CONTAINER_NAME" \
  VERIFIER_SHARED_CERT_FILE="$SHARED_CERT_FILE" \
  VERIFIER_SHARED_KEY_FILE="$SHARED_KEY_FILE" \
  ./scripts/start-local-verifier.sh
)

print_runtime_summary

section "Startup Grace Period"
sleep 5

section "Startup Hint"
printf 'Run %s/smoke-local-all.sh to verify the stack before recording.\n' "$SCRIPT_DIR"
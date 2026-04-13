#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

quiet=false
if [[ "${1:-}" == "--quiet" ]]; then
  quiet=true
fi

if [[ "$quiet" != true ]]; then
  section "Stopping Python Services"
fi

stop_pid_file "$PID_DIR/auth-server.pid"
stop_pid_file "$PID_DIR/issuer-backend.pid"
stop_pid_file "$PID_DIR/issuer-frontend.pid"

kill_port_if_listening "$AUTH_PORT"
kill_port_if_listening "$ISSUER_PORT"
kill_port_if_listening "$FRONTEND_PORT"

if [[ "$quiet" != true ]]; then
  section "Stopping Docker Verifier Stack"
fi

if [[ -x "$VERIFIER_REPO/scripts/stop-local-verifier.sh" ]]; then
  (
    cd "$VERIFIER_REPO"
    VERIFIER_PUBLIC_HOST="$VERIFIER_PUBLIC_HOST" \
    VERIFIER_PUBLIC_URL="$VERIFIER_PUBLIC_URL" \
    VERIFIER_IRISHLIFE_CUSTOMERBASEURL="$VERIFIER_PUBLIC_URL" \
    VERIFIER_TLS_HOST_PORT="${VERIFIER_TLS_HOST_PORT:-443}" \
    VERIFIER_BACKEND_HOST_PORT="${VERIFIER_BACKEND_HOST_PORT:-8080}" \
    VERIFIER_UI_HOST_PORT="${VERIFIER_UI_HOST_PORT:-4300}" \
    VERIFIER_BACKEND_CONTAINER_NAME="${VERIFIER_BACKEND_CONTAINER_NAME:-verifier-backend}" \
    VERIFIER_UI_CONTAINER_NAME="${VERIFIER_UI_CONTAINER_NAME:-verifier-ui}" \
    VERIFIER_HAPROXY_CONTAINER_NAME="${VERIFIER_HAPROXY_CONTAINER_NAME:-verifier-haproxy}" \
    VERIFIER_SHARED_CERT_FILE="$SHARED_CERT_FILE" \
    VERIFIER_SHARED_KEY_FILE="$SHARED_KEY_FILE" \
    ./scripts/stop-local-verifier.sh >/dev/null 2>&1 || true
  )
fi

if [[ "$quiet" != true ]]; then
  section "Stopped"
  printf 'Local stack stopped.\n'
fi
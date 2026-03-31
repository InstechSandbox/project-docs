#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

WALLET_LOCAL_CERT_FILE="${WALLET_LOCAL_CERT_FILE:-$WALLET_REPO/network-logic/src/main/res/raw/backend_cert.pem}"

require_command openssl

mkdir -p "$(dirname "$SHARED_CERT_FILE")"
mkdir -p "$(dirname "$WALLET_LOCAL_CERT_FILE")"

cert_has_san_entry() {
  local cert_file=$1
  local entry=$2

  openssl x509 -in "$cert_file" -noout -ext subjectAltName 2>/dev/null | grep -Fq "$entry"
}

cert_matches_runtime_host() {
  local cert_file=$1

  [[ -f "$cert_file" ]] || return 1

  if ! openssl x509 -in "$cert_file" -noout -subject 2>/dev/null | grep -Fq "CN=$PUBLIC_HOST"; then
    return 1
  fi

  if ! cert_has_san_entry "$cert_file" "$PUBLIC_HOST"; then
    return 1
  fi

  if [[ -n "${DETECTED_LAN_IP:-}" ]] && [[ "$DETECTED_LAN_IP" != "127.0.0.1" ]] && [[ "$DETECTED_LAN_IP" != "$PUBLIC_HOST" ]]; then
    cert_has_san_entry "$cert_file" "$DETECTED_LAN_IP" || return 1
  fi

  cert_has_san_entry "$cert_file" "127.0.0.1" || return 1
  cert_has_san_entry "$cert_file" "localhost" || return 1
}

generate_shared_cert() {
  local temp_config
  temp_config=$(mktemp)
  trap 'rm -f "$temp_config"' RETURN

  local alt_names="IP.1 = 127.0.0.1
DNS.1 = localhost"
  local next_index=2

  case "$PUBLIC_HOST" in
    *[!0-9.]*)
      alt_names+="
DNS.2 = $PUBLIC_HOST"
      ;;
    *)
      alt_names="IP.1 = $PUBLIC_HOST
IP.2 = 127.0.0.1
DNS.1 = localhost"
      next_index=3
      ;;
  esac

  if [[ -n "${DETECTED_LAN_IP:-}" ]] && [[ "$DETECTED_LAN_IP" != "127.0.0.1" ]] && [[ "$DETECTED_LAN_IP" != "$PUBLIC_HOST" ]]; then
    alt_names+="
IP.${next_index} = ${DETECTED_LAN_IP}"
  fi

  cat >"$temp_config" <<EOF
[req]
prompt = no
distinguished_name = dn
x509_extensions = v3_req

[dn]
CN = ${PUBLIC_HOST}

[v3_req]
subjectAltName = @alt_names

[alt_names]
${alt_names}
EOF

  openssl ecparam -name prime256v1 -genkey -noout -out "$SHARED_KEY_FILE"
  openssl req -new -x509 -sha256 -days 365 -key "$SHARED_KEY_FILE" -out "$SHARED_CERT_FILE" -config "$temp_config"
}

section "Shared Certificate"

shared_cert_changed=false

if [[ ! -f "$SHARED_CERT_FILE" ]] || [[ ! -f "$SHARED_KEY_FILE" ]] || ! cert_matches_runtime_host "$SHARED_CERT_FILE"; then
  printf 'Refreshing shared local certificate for %s\n' "$PUBLIC_HOST"
  generate_shared_cert
  shared_cert_changed=true
else
  printf 'Shared local certificate already matches %s\n' "$PUBLIC_HOST"
fi

if [[ ! -f "$WALLET_LOCAL_CERT_FILE" ]] || ! cmp -s "$SHARED_CERT_FILE" "$WALLET_LOCAL_CERT_FILE"; then
  cp "$SHARED_CERT_FILE" "$WALLET_LOCAL_CERT_FILE"
  printf 'Synced wallet local certificate: %s\n' "$WALLET_LOCAL_CERT_FILE"
  shared_cert_changed=true
else
  printf 'Wallet local certificate already matches shared cert\n'
fi

if [[ "$shared_cert_changed" == true ]]; then
  printf 'Certificate fingerprint: '
  openssl x509 -in "$SHARED_CERT_FILE" -noout -fingerprint -sha256 | sed 's/^SHA256 Fingerprint=//'
fi
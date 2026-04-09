#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

WALLET_LOCAL_CERT_FILE="${WALLET_LOCAL_CERT_FILE:-$WALLET_REPO/network-logic/src/main/res/raw/backend_cert.pem}"
UTOPIA_SIGNER_KEY_FILE="${UTOPIA_SIGNER_KEY_FILE:-$ISSUER_REPO/local/privKey/PID-DS-0001_UT.pem}"
UTOPIA_SIGNER_CERT_PEM="${UTOPIA_SIGNER_CERT_PEM:-$ISSUER_REPO/local/cert/PID-DS-0001_UT_cert.pem}"
UTOPIA_SIGNER_CERT_DER="${UTOPIA_SIGNER_CERT_DER:-$ISSUER_REPO/local/cert/PID-DS-0001_UT_cert.der}"
SYNC_WALLET_CERT=false

if [[ "${1:-}" == "--sync-wallet-cert" ]]; then
  SYNC_WALLET_CERT=true
elif [[ -n "${1:-}" ]]; then
  fail "Unknown argument: $1"
fi

require_command openssl

mkdir -p "$(dirname "$SHARED_CERT_FILE")"
mkdir -p "$(dirname "$WALLET_LOCAL_CERT_FILE")"

cert_has_san_entry() {
  local cert_file=$1
  local entry=$2

  openssl x509 -in "$cert_file" -noout -ext subjectAltName 2>/dev/null | grep -Fq "$entry"
}

public_key_fingerprint() {
  local mode=$1
  local path=$2

  case "$mode" in
    key)
      openssl pkey -in "$path" -pubout -outform pem 2>/dev/null | openssl sha256 | awk '{print $2}'
      ;;
    cert-pem)
      openssl x509 -in "$path" -pubkey -noout 2>/dev/null | openssl sha256 | awk '{print $2}'
      ;;
    cert-der)
      openssl x509 -in "$path" -inform der -pubkey -noout 2>/dev/null | openssl sha256 | awk '{print $2}'
      ;;
    *)
      return 1
      ;;
  esac
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
  cert_has_san_entry "$cert_file" "URI:$AUTH_URL" || return 1
  cert_has_san_entry "$cert_file" "URI:$ISSUER_URL" || return 1
  cert_has_san_entry "$cert_file" "URI:$FRONTEND_URL" || return 1
  cert_has_san_entry "$cert_file" "URI:$VERIFIER_PUBLIC_URL" || return 1
}

utopia_signer_cert_matches_issuer_identity() {
  local key_file=$1
  local cert_pem=$2
  local cert_der=$3
  local key_fp
  local pem_fp
  local der_fp

  [[ -f "$key_file" ]] || return 1
  [[ -f "$cert_pem" ]] || return 1
  [[ -f "$cert_der" ]] || return 1

  cert_has_san_entry "$cert_pem" "URI:$ISSUER_URL" || return 1
  cert_has_san_entry "$cert_pem" "$PUBLIC_HOST" || return 1

  key_fp=$(public_key_fingerprint key "$key_file") || return 1
  pem_fp=$(public_key_fingerprint cert-pem "$cert_pem") || return 1
  der_fp=$(public_key_fingerprint cert-der "$cert_der") || return 1

  [[ -n "$key_fp" ]] || return 1
  [[ "$key_fp" == "$pem_fp" ]] || return 1
  [[ "$key_fp" == "$der_fp" ]] || return 1
}

generate_shared_cert() {
  local temp_config
  temp_config=$(mktemp)
  trap 'rm -f "$temp_config"' RETURN

  local alt_names="IP.1 = 127.0.0.1
DNS.1 = localhost
URI.1 = ${AUTH_URL}
URI.2 = ${ISSUER_URL}
URI.3 = ${FRONTEND_URL}
URI.4 = ${VERIFIER_PUBLIC_URL}"
  local next_dns_index=2
  local next_ip_index=2

  case "$PUBLIC_HOST" in
    *[!0-9.]*)
      alt_names+="
DNS.${next_dns_index} = $PUBLIC_HOST"
      next_dns_index=$((next_dns_index + 1))
      ;;
    *)
      alt_names="IP.1 = $PUBLIC_HOST
IP.2 = 127.0.0.1
DNS.1 = localhost
URI.1 = ${AUTH_URL}
URI.2 = ${ISSUER_URL}
URI.3 = ${FRONTEND_URL}
URI.4 = ${VERIFIER_PUBLIC_URL}"
      next_ip_index=3
      ;;
  esac

  if [[ -n "${DETECTED_LAN_IP:-}" ]] && [[ "$DETECTED_LAN_IP" != "127.0.0.1" ]] && [[ "$DETECTED_LAN_IP" != "$PUBLIC_HOST" ]]; then
    alt_names+="
IP.${next_ip_index} = ${DETECTED_LAN_IP}"
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

generate_utopia_signer_cert() {
  local temp_config
  temp_config=$(mktemp)
  trap 'rm -f "$temp_config"' RETURN

  local alt_names="URI.1 = ${ISSUER_URL}"
  local next_dns_index=1
  local next_ip_index=1

  case "$PUBLIC_HOST" in
    *[!0-9.]*)
      alt_names+="
DNS.${next_dns_index} = $PUBLIC_HOST"
      next_dns_index=$((next_dns_index + 1))
      ;;
    *)
      alt_names+="
IP.${next_ip_index} = $PUBLIC_HOST"
      next_ip_index=$((next_ip_index + 1))
      ;;
  esac

  if [[ -n "${DETECTED_LAN_IP:-}" ]] && [[ "$DETECTED_LAN_IP" != "$PUBLIC_HOST" ]] && [[ "$DETECTED_LAN_IP" != "127.0.0.1" ]]; then
    alt_names+="
IP.${next_ip_index} = ${DETECTED_LAN_IP}"
    next_ip_index=$((next_ip_index + 1))
  fi

  alt_names+="
IP.${next_ip_index} = 127.0.0.1
DNS.${next_dns_index} = localhost"

  cat >"$temp_config" <<EOF
[req]
prompt = no
distinguished_name = dn
x509_extensions = v3_req

[dn]
CN = Local Utopia DS

[v3_req]
basicConstraints = critical,CA:false
keyUsage = critical,digitalSignature
subjectAltName = @alt_names

[alt_names]
${alt_names}
EOF

  openssl req -new -x509 -sha256 -days 365 -key "$UTOPIA_SIGNER_KEY_FILE" -out "$UTOPIA_SIGNER_CERT_PEM" -config "$temp_config"
  openssl x509 -in "$UTOPIA_SIGNER_CERT_PEM" -outform der -out "$UTOPIA_SIGNER_CERT_DER"
}

section "Shared Certificate"

shared_cert_changed=false
wallet_cert_changed=false
utopia_signer_cert_changed=false

require_file "$UTOPIA_SIGNER_KEY_FILE"
mkdir -p "$(dirname "$UTOPIA_SIGNER_CERT_PEM")"
mkdir -p "$(dirname "$UTOPIA_SIGNER_CERT_DER")"

if [[ ! -f "$SHARED_CERT_FILE" ]] || [[ ! -f "$SHARED_KEY_FILE" ]] || ! cert_matches_runtime_host "$SHARED_CERT_FILE"; then
  printf 'Refreshing shared local certificate for %s\n' "$PUBLIC_HOST"
  generate_shared_cert
  shared_cert_changed=true
else
  printf 'Shared local certificate already matches %s\n' "$PUBLIC_HOST"
fi

if [[ "$SYNC_WALLET_CERT" == true ]]; then
  if [[ ! -f "$WALLET_LOCAL_CERT_FILE" ]] || ! cmp -s "$SHARED_CERT_FILE" "$WALLET_LOCAL_CERT_FILE"; then
    cp "$SHARED_CERT_FILE" "$WALLET_LOCAL_CERT_FILE"
    printf 'Synced wallet local certificate: %s\n' "$WALLET_LOCAL_CERT_FILE"
    wallet_cert_changed=true
  else
    printf 'Wallet local certificate already matches shared cert\n'
  fi
else
  if [[ ! -f "$WALLET_LOCAL_CERT_FILE" ]]; then
    printf 'Wallet local certificate missing and was not changed during normal refresh\n'
    printf 'Run %s --sync-wallet-cert before rebuilding/installing the wallet APK\n' "$0"
  elif cmp -s "$SHARED_CERT_FILE" "$WALLET_LOCAL_CERT_FILE"; then
    printf 'Wallet local certificate already matches shared cert\n'
  else
    printf 'Wallet local certificate differs from shared cert and was left unchanged\n'
    printf 'Run %s --sync-wallet-cert before rebuilding/installing the wallet APK\n' "$0"
  fi
fi

if [[ "$shared_cert_changed" == true || "$wallet_cert_changed" == true ]]; then
  printf 'Certificate fingerprint: '
  openssl x509 -in "$SHARED_CERT_FILE" -noout -fingerprint -sha256 | sed 's/^SHA256 Fingerprint=//'
fi

section "Issuer Signer Certificate"

if ! utopia_signer_cert_matches_issuer_identity "$UTOPIA_SIGNER_KEY_FILE" "$UTOPIA_SIGNER_CERT_PEM" "$UTOPIA_SIGNER_CERT_DER"; then
  printf 'Refreshing Utopia SD-JWT signer certificate for %s\n' "$ISSUER_URL"
  generate_utopia_signer_cert
  utopia_signer_cert_changed=true
else
  printf 'Utopia SD-JWT signer certificate already matches %s\n' "$ISSUER_URL"
fi

if [[ "$utopia_signer_cert_changed" == true ]]; then
  printf 'Signer certificate fingerprint: '
  openssl x509 -in "$UTOPIA_SIGNER_CERT_PEM" -noout -fingerprint -sha256 | sed 's/^SHA256 Fingerprint=//'
fi
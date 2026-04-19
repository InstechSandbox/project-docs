#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

require_command openssl
require_dir "$ISSUER_REPO"
require_dir "$WALLET_REPO"

PYTHON_BIN="${PYTHON_BIN:-$ISSUER_REPO/.venv/bin/python}"
if [[ ! -x "$PYTHON_BIN" ]]; then
  PYTHON_BIN="${PYTHON_BIN_FALLBACK:-python3}"
fi

ISSUER_CERT_DIR="$ISSUER_REPO/local/cert"
ISSUER_KEY_DIR="$ISSUER_REPO/local/privKey"
ANDROID_LOCAL_ROOT="$WALLET_REPO/resources-logic/src/main/res/raw/pidissuerca_local_ut.pem"
IOS_LOCAL_ROOT="$IOS_WALLET_REPO/Wallet/Certificate/pidissuerca_local_ut.der"
SYNC_IOS_LOCAL_ROOT=true

if [[ ! -d "$IOS_WALLET_REPO" ]]; then
  SYNC_IOS_LOCAL_ROOT=false
fi

IACA_KEY="$ISSUER_KEY_DIR/PID-IACA-LOCAL-UT.pem"
IACA_CERT_PEM="$ISSUER_CERT_DIR/PIDIssuerCALocalUT.pem"
DS_KEY="$ISSUER_KEY_DIR/PID-DS-LOCAL-UT.pem"
DS_CERT_PEM="$ISSUER_CERT_DIR/PID-DS-LOCAL-UT_cert.pem"
DS_CERT_DER="$ISSUER_CERT_DIR/PID-DS-LOCAL-UT_cert.der"

mkdir -p "$ISSUER_CERT_DIR" "$ISSUER_KEY_DIR" "$(dirname "$ANDROID_LOCAL_ROOT")"

if [[ "$SYNC_IOS_LOCAL_ROOT" == true ]]; then
  mkdir -p "$(dirname "$IOS_LOCAL_ROOT")"
fi

IACA_KEY="$IACA_KEY" \
IACA_CERT_PEM="$IACA_CERT_PEM" \
DS_KEY="$DS_KEY" \
DS_CERT_PEM="$DS_CERT_PEM" \
ISSUER_URL="$ISSUER_URL" \
PUBLIC_HOST="$PUBLIC_HOST" \
DETECTED_LAN_IP="${DETECTED_LAN_IP:-}" \
"$PYTHON_BIN" - <<'PY'
from datetime import datetime, timedelta, timezone
import ipaddress
from pathlib import Path
import os
import sys
from urllib.parse import urlparse

try:
  from cryptography import x509
  from cryptography.hazmat.primitives import hashes, serialization
  from cryptography.hazmat.primitives.asymmetric import ec
  from cryptography.x509.oid import ExtendedKeyUsageOID, NameOID, ObjectIdentifier
except ImportError as exc:
  sys.stderr.write(
    "cryptography is required to generate the local mdoc signer chain. "
    "Run ./bootstrap-local-python-venvs.sh first or set PYTHON_BIN to a Python with cryptography installed.\n"
  )
  raise

validity_start = datetime.now(timezone.utc) - timedelta(minutes=5)
validity_end = validity_start + timedelta(days=3650)
issuer_alt_name = x509.UniformResourceIdentifier(
  "https://github.com/eu-digital-identity-wallet/architecture-and-reference-framework"
)
issuer_url = os.environ["ISSUER_URL"]
issuer_url_host = urlparse(issuer_url).hostname
crl_dp = x509.CRLDistributionPoints(
  [
    x509.DistributionPoint(
      full_name=[x509.UniformResourceIdentifier("https://local.eudiw.dev/crl/pid_ca_local_ut.crl")],
      relative_name=None,
      reasons=None,
      crl_issuer=None,
    )
  ]
)

def write_private_key(path: str, key: ec.EllipticCurvePrivateKey) -> None:
  Path(path).write_bytes(
    key.private_bytes(
      encoding=serialization.Encoding.PEM,
      format=serialization.PrivateFormat.TraditionalOpenSSL,
      encryption_algorithm=serialization.NoEncryption(),
    )
  )

def build_name(common_name: str) -> x509.Name:
  return x509.Name(
    [
      x509.NameAttribute(NameOID.COMMON_NAME, common_name),
      x509.NameAttribute(NameOID.ORGANIZATION_NAME, "EUDI Wallet Reference Implementation"),
      x509.NameAttribute(NameOID.COUNTRY_NAME, "UT"),
    ]
  )

def make_subject_alt_names() -> x509.SubjectAlternativeName:
  general_names: list[x509.GeneralName] = [
    x509.UniformResourceIdentifier(issuer_url),
    x509.DNSName("localhost"),
    x509.IPAddress(ipaddress.ip_address("127.0.0.1")),
  ]

  for candidate in [issuer_url_host, os.environ.get("PUBLIC_HOST"), os.environ.get("DETECTED_LAN_IP")]:
    if not candidate:
      continue

    try:
      general_names.append(x509.IPAddress(ipaddress.ip_address(candidate)))
    except ValueError:
      general_names.append(x509.DNSName(candidate))

  deduplicated: list[x509.GeneralName] = []
  seen = set()
  for entry in general_names:
    key = (entry.__class__.__name__, entry.value)
    if key in seen:
      continue
    seen.add(key)
    deduplicated.append(entry)

  return x509.SubjectAlternativeName(deduplicated)

subject_alt_names = make_subject_alt_names()

iaca_key = ec.generate_private_key(ec.SECP256R1())
iaca_subject = build_name("PID Issuer CA - LOCAL UT")
iaca_cert = (
  x509.CertificateBuilder()
  .subject_name(iaca_subject)
  .issuer_name(iaca_subject)
  .public_key(iaca_key.public_key())
  .serial_number(x509.random_serial_number())
  .not_valid_before(validity_start)
  .not_valid_after(validity_end)
  .add_extension(x509.BasicConstraints(ca=True, path_length=0), critical=True)
  .add_extension(x509.KeyUsage(digital_signature=False, key_encipherment=False, content_commitment=False, data_encipherment=False, key_agreement=False, key_cert_sign=True, crl_sign=True, encipher_only=False, decipher_only=False), critical=True)
  .add_extension(x509.ExtendedKeyUsage([ObjectIdentifier("1.3.130.2.0.0.1.7")]), critical=True)
  .add_extension(x509.SubjectKeyIdentifier.from_public_key(iaca_key.public_key()), critical=False)
  .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(iaca_key.public_key()), critical=False)
  .add_extension(x509.IssuerAlternativeName([issuer_alt_name]), critical=False)
  .add_extension(crl_dp, critical=False)
  .sign(private_key=iaca_key, algorithm=hashes.SHA384())
)

ds_key = ec.generate_private_key(ec.SECP256R1())
ds_subject = build_name("PID DS - LOCAL UT")
ds_cert = (
  x509.CertificateBuilder()
  .subject_name(ds_subject)
  .issuer_name(iaca_subject)
  .public_key(ds_key.public_key())
  .serial_number(x509.random_serial_number())
  .not_valid_before(validity_start)
  .not_valid_after(validity_end)
  .add_extension(x509.BasicConstraints(ca=False, path_length=None), critical=True)
  .add_extension(x509.KeyUsage(digital_signature=True, key_encipherment=False, content_commitment=False, data_encipherment=False, key_agreement=False, key_cert_sign=False, crl_sign=False, encipher_only=False, decipher_only=False), critical=True)
  .add_extension(x509.ExtendedKeyUsage([ObjectIdentifier("1.3.130.2.0.0.1.2")]), critical=True)
  .add_extension(subject_alt_names, critical=False)
  .add_extension(x509.SubjectKeyIdentifier.from_public_key(ds_key.public_key()), critical=False)
  .add_extension(x509.AuthorityKeyIdentifier.from_issuer_public_key(iaca_key.public_key()), critical=False)
  .add_extension(x509.IssuerAlternativeName([issuer_alt_name]), critical=False)
  .add_extension(crl_dp, critical=False)
  .sign(private_key=iaca_key, algorithm=hashes.SHA256())
)

write_private_key(os.environ["IACA_KEY"], iaca_key)
write_private_key(os.environ["DS_KEY"], ds_key)
Path(os.environ["IACA_CERT_PEM"]).write_bytes(iaca_cert.public_bytes(serialization.Encoding.PEM))
Path(os.environ["DS_CERT_PEM"]).write_bytes(ds_cert.public_bytes(serialization.Encoding.PEM))
PY

openssl x509 -in "$DS_CERT_PEM" -outform der -out "$DS_CERT_DER"
cp "$IACA_CERT_PEM" "$ANDROID_LOCAL_ROOT"

if [[ "$SYNC_IOS_LOCAL_ROOT" == true ]]; then
  openssl x509 -in "$IACA_CERT_PEM" -outform der -out "$IOS_LOCAL_ROOT"
fi

section "Local Mdoc Signer Chain"
openssl x509 -in "$IACA_CERT_PEM" -noout -subject -issuer -dates
openssl x509 -in "$DS_CERT_PEM" -noout -subject -issuer -dates
openssl x509 -in "$DS_CERT_PEM" -noout -ext subjectAltName
openssl verify -CAfile "$IACA_CERT_PEM" "$DS_CERT_PEM"

section "Wallet Trust Roots"
printf 'Android local root: %s\n' "$ANDROID_LOCAL_ROOT"

if [[ "$SYNC_IOS_LOCAL_ROOT" == true ]]; then
  printf 'iOS local root: %s\n' "$IOS_LOCAL_ROOT"
else
  printf 'iOS local root: skipped (repo not present at %s)\n' "$IOS_WALLET_REPO"
fi

section "Issuer Signer Material"
printf 'IACA key: %s\n' "$IACA_KEY"
printf 'IACA cert: %s\n' "$IACA_CERT_PEM"
printf 'DS key: %s\n' "$DS_KEY"
printf 'DS cert: %s\n' "$DS_CERT_DER"
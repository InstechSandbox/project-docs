#!/bin/bash

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

IOS_WALLET_REPO="${IOS_WALLET_REPO:-$CODE_ROOT/eudi-app-ios-wallet-ui}"
COMPLIANCE_OUTPUT_ROOT="${COMPLIANCE_OUTPUT_ROOT:-$PROJECT_DOCS_DIR/.local/mobile-compliance}"
COMPLIANCE_CACHE_ROOT="${COMPLIANCE_CACHE_ROOT:-$PROJECT_DOCS_DIR/.local/mobile-compliance-cache}"
RELEASE_TEMPLATE="$PROJECT_DOCS_DIR/docs/Mobile_App_Release_Record_Template.md"
COMPLIANCE_GUIDE_REL="project-docs/docs/Mobile_App_Distribution_Compliance.md"
INVENTORY_GUIDE_REL="project-docs/docs/Mobile_Third_Party_Notice_Inventory.md"

usage() {
  cat <<'EOF'
Usage:
  generate-mobile-compliance-bundle.sh android <release-label>
  generate-mobile-compliance-bundle.sh ios <release-label>
  generate-mobile-compliance-bundle.sh all <release-label>

Generates a release-sidecar compliance bundle under:
  project-docs/.local/mobile-compliance/<release-label>-<platform>/

The bundle includes:
- repository LICENSE and NOTICE copies
- git source metadata
- a prefilled release-record skeleton
- an extracted third-party dependency inventory from the platform manifest
- harvested third-party license metadata
- saved license texts where they can be resolved automatically
- a generated markdown notice appendix

This script does not determine final runtime linkage or fetch every third-party license text.
It reduces manual work by generating the release-sidecar structure that should accompany
tester distributions.
EOF
}

require_repo_artifacts() {
  local repo=$1
  require_dir "$repo"
  require_file "$repo/LICENSE.txt"
  require_file "$repo/NOTICE.txt"
}

git_value() {
  local repo=$1
  local args=$2
  (
    cd "$repo"
    eval "$args"
  )
}

git_remote_url() {
  local repo=$1
  (
    cd "$repo"
    git remote get-url origin
  )
}

git_branch_name() {
  local repo=$1
  (
    cd "$repo"
    git branch --show-current
  )
}

git_commit_sha() {
  local repo=$1
  (
    cd "$repo"
    git rev-parse HEAD
  )
}

git_commit_date() {
  local repo=$1
  (
    cd "$repo"
    git log -1 --date=short --format=%cd
  )
}

git_short_summary() {
  local repo=$1
  (
    cd "$repo"
    git log -1 --format=%s
  )
}

normalize_remote_url() {
  local url=$1

  if [[ "$url" == git@github.com:* ]]; then
    url="https://github.com/${url#git@github.com:}"
  fi

  case "$url" in
    *.git)
      printf '%s\n' "${url%.git}"
      ;;
    *)
      printf '%s\n' "$url"
      ;;
  esac
}

generate_android_inventory() {
  local repo=$1
  local output_tsv=$2
  local manifest="$repo/gradle/libs.versions.toml"

  require_file "$manifest"

  python3 - "$manifest" > "$output_tsv" <<'PY'
import csv
import sys
import tomllib

manifest = sys.argv[1]
with open(manifest, 'rb') as handle:
    data = tomllib.load(handle)

versions = data.get('versions', {})
libraries = data.get('libraries', {})

writer = csv.writer(sys.stdout, delimiter='\t', lineterminator='\n')
writer.writerow(['alias', 'coordinate', 'version', 'version_source', 'status'])

for alias in sorted(libraries):
    spec = libraries[alias]
    coordinate = spec.get('module', '')
    if not coordinate:
        group = spec.get('group', '')
        name = spec.get('name', '')
        if group and name:
            coordinate = f'{group}:{name}'

    version = ''
    version_source = ''
    status = 'ok'

    version_spec = spec.get('version')
    if isinstance(version_spec, dict):
        ref = version_spec.get('ref', '')
        version_source = f'ref:{ref}' if ref else 'inline-dict'
        if ref:
            version = versions.get(ref, '')
            if not version:
                status = f'missing-version-ref:{ref}'
        elif 'require' in version_spec:
            version = version_spec.get('require', '')
            version_source = 'require'
    elif isinstance(version_spec, str):
        version = version_spec
        version_source = 'inline'
    else:
        version_source = 'none'
        status = 'version-managed-or-unresolved'

    writer.writerow([alias, coordinate, version, version_source, status])
PY
}

generate_ios_inventory() {
  local repo=$1
  local output_tsv=$2
  local manifest="$repo/EudiReferenceWallet.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved"

  require_file "$manifest"
  python3 - "$manifest" > "$output_tsv" <<'PY'
import csv
import json
import sys

manifest = sys.argv[1]
with open(manifest, 'r', encoding='utf-8') as handle:
    data = json.load(handle)

writer = csv.writer(sys.stdout, delimiter='\t', lineterminator='\n')
writer.writerow(['identity', 'location', 'version', 'revision', 'branch'])

for pin in sorted(data.get('pins', []), key=lambda item: item.get('identity', '')):
    state = pin.get('state', {})
    writer.writerow([
        pin.get('identity', ''),
        pin.get('location', ''),
        state.get('version', ''),
        state.get('revision', ''),
        state.get('branch', ''),
    ])
PY
}

harvest_android_notice_bundle() {
  local inventory_tsv=$1
  local third_party_dir=$2
  local cache_dir=$3

  require_command python3

  python3 - "$inventory_tsv" "$third_party_dir" "$cache_dir" <<'PY'
import csv
import hashlib
import re
import sys
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import urlparse

inventory_path = Path(sys.argv[1])
third_party_dir = Path(sys.argv[2])
cache_dir = Path(sys.argv[3]) / 'android'
license_dir = third_party_dir / 'license_texts'
metadata_path = third_party_dir / 'license_metadata.tsv'
summary_path = third_party_dir / 'THIRD_PARTY_NOTICES.md'

cache_dir.mkdir(parents=True, exist_ok=True)
license_dir.mkdir(parents=True, exist_ok=True)

STANDARD_LICENSE_URLS = {
    'Apache License, Version 2.0': 'https://www.apache.org/licenses/LICENSE-2.0.txt',
    'Apache 2.0': 'https://www.apache.org/licenses/LICENSE-2.0.txt',
    'Apache-2.0': 'https://www.apache.org/licenses/LICENSE-2.0.txt',
}

def safe_name(value: str) -> str:
    return re.sub(r'[^A-Za-z0-9._-]+', '_', value).strip('_') or 'item'

def fetch_url(url: str, cache_prefix: str):
    cache_key = hashlib.sha256(url.encode('utf-8')).hexdigest()
    body_path = cache_dir / f'{cache_prefix}-{cache_key}.body'
    meta_path = cache_dir / f'{cache_prefix}-{cache_key}.meta'
    if body_path.exists() and meta_path.exists():
        content_type = meta_path.read_text(encoding='utf-8').strip()
        return body_path.read_bytes(), content_type, None

    request = urllib.request.Request(url, headers={'User-Agent': 'InstechSandbox-Mobile-Compliance/1.0'})
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read()
            content_type = response.headers.get('Content-Type', 'application/octet-stream')
    except Exception as exc:  # noqa: BLE001
        return None, None, str(exc)

    body_path.write_bytes(body)
    meta_path.write_text(content_type, encoding='utf-8')
    return body, content_type, None

def extension_for(content_type: str, url: str) -> str:
    lowered = (content_type or '').lower()
    if 'html' in lowered:
        return '.html'
    if 'json' in lowered:
        return '.json'
    if 'xml' in lowered:
        return '.xml'
    suffix = Path(urlparse(url).path).suffix
    if suffix:
        return suffix
    return '.txt'

def findall_local(root, local_name):
    return [elem for elem in root.iter() if elem.tag.endswith(local_name)]

def child_text(element, local_name):
  for child in list(element):
    if child.tag.endswith(local_name) and child.text:
      return child.text.strip()
  return ''

def candidate_pom_urls(coordinate: str, version: str):
  group_id, artifact_id = coordinate.split(':', 1)
  group_path = group_id.replace('.', '/')
  base_name = f'{artifact_id}-{version}.pom'
  return [
    f'https://repo1.maven.org/maven2/{group_path}/{artifact_id}/{version}/{base_name}',
    f'https://dl.google.com/dl/android/maven2/{group_path}/{artifact_id}/{version}/{base_name}',
    f'https://jitpack.io/{group_path}/{artifact_id}/{version}/{base_name}',
  ]

def fetch_first_available(urls, cache_prefix):
  last_error = None
  for url in urls:
    body, content_type, error = fetch_url(url, cache_prefix)
    if error is None and body is not None:
      return body, content_type, url, None
    last_error = error
  return None, None, '', last_error or 'no-source-tried'

rows = list(csv.DictReader(inventory_path.open('r', encoding='utf-8'), delimiter='\t'))
bom_versions = {}

for row in rows:
  if row.get('coordinate') == 'androidx.compose:compose-bom' and row.get('version'):
    bom_body, _bom_content_type, _bom_url, bom_error = fetch_first_available(
      candidate_pom_urls(row['coordinate'], row['version']),
      'bom-pom'
    )
    if bom_error is None and bom_body is not None:
      try:
        bom_root = ET.fromstring(bom_body)
        for dependency in findall_local(bom_root, 'dependency'):
          group_id = child_text(dependency, 'groupId')
          artifact_id = child_text(dependency, 'artifactId')
          version = child_text(dependency, 'version')
          if group_id and artifact_id and version:
            bom_versions[f'{group_id}:{artifact_id}'] = version
      except Exception:
        pass
    break

with metadata_path.open('w', encoding='utf-8', newline='') as handle:
    writer = csv.writer(handle, delimiter='\t', lineterminator='\n')
    writer.writerow(['alias', 'coordinate', 'version', 'pom_url', 'license_names', 'license_urls', 'saved_files', 'status'])

    summary_lines = [
        '# Android Third-Party Notices',
        '',
        'This file was generated automatically from the Android version catalog and the corresponding Maven POM metadata.',
        '',
        '| Alias | Coordinate | Version | Licenses | Status |',
        '| --- | --- | --- | --- | --- |',
    ]

    for row in rows:
        alias = row.get('alias', '')
        coordinate = row.get('coordinate', '')
        version = row.get('version', '')
        status = row.get('status', '')
        pom_url = ''
        license_names = []
        license_urls = []
        saved_files = []

        if coordinate and not version and coordinate in bom_versions:
          version = bom_versions[coordinate]
          status = 'resolved-from-bom'

        if coordinate and version and ':' in coordinate:
            pom_body, _content_type, pom_url, pom_error = fetch_first_available(
                candidate_pom_urls(coordinate, version),
                'pom'
            )
            if pom_error:
                status = f'pom-fetch-failed:{pom_error}'
            elif pom_body is not None:
                try:
                    root = ET.fromstring(pom_body)
                    license_blocks = findall_local(root, 'license')
                    if not license_blocks:
                        status = 'no-license-block-in-pom'
                    for index, license_block in enumerate(license_blocks, start=1):
                        name_elem = next((child for child in list(license_block) if child.tag.endswith('name')), None)
                        url_elem = next((child for child in list(license_block) if child.tag.endswith('url')), None)
                        name_value = (name_elem.text or '').strip() if name_elem is not None and name_elem.text else ''
                        url_value = (url_elem.text or '').strip() if url_elem is not None and url_elem.text else ''
                        effective_url = STANDARD_LICENSE_URLS.get(name_value, url_value)
                        if name_value:
                            license_names.append(name_value)
                        if effective_url:
                            license_urls.append(effective_url)
                            license_body, content_type, license_error = fetch_url(effective_url, 'license')
                            if license_error is None and license_body is not None:
                                ext = extension_for(content_type, effective_url)
                                file_name = f'{safe_name(alias)}__{index}{ext}'
                                output_path = license_dir / file_name
                                output_path.write_bytes(license_body)
                                saved_files.append(f'license_texts/{file_name}')
                            else:
                                status = f'license-fetch-warning:{license_error}'
                    if license_names and status == 'ok':
                        status = 'harvested'
                except Exception as exc:  # noqa: BLE001
                    status = f'pom-parse-failed:{exc}'
        elif coordinate and not version:
            status = status or 'version-unresolved'
        else:
            status = status or 'coordinate-unresolved'

        writer.writerow([
            alias,
            coordinate,
            version,
            pom_url,
            ' | '.join(license_names),
            ' | '.join(license_urls),
            ' | '.join(saved_files),
            status,
        ])
        summary_lines.append(
            '| {} | {} | {} | {} | {} |'.format(
                alias or '-',
                coordinate or '-',
                version or '-',
                '<br>'.join(license_names) if license_names else '-',
                status or '-',
            )
        )

summary_lines.extend([
    '',
    'Generated files under `license_texts/` contain license texts fetched automatically where they could be resolved from Maven metadata.',
    'Dependencies with unresolved versions or missing POM license blocks still require review before distribution.',
])
summary_path.write_text('\n'.join(summary_lines) + '\n', encoding='utf-8')
PY
}

harvest_ios_notice_bundle() {
  local inventory_tsv=$1
  local third_party_dir=$2
  local cache_dir=$3

  require_command python3

  python3 - "$inventory_tsv" "$third_party_dir" "$cache_dir" <<'PY'
import base64
import csv
import hashlib
import json
import re
import sys
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import urlparse

inventory_path = Path(sys.argv[1])
third_party_dir = Path(sys.argv[2])
cache_dir = Path(sys.argv[3]) / 'ios'
license_dir = third_party_dir / 'license_texts'
metadata_path = third_party_dir / 'license_metadata.tsv'
summary_path = third_party_dir / 'THIRD_PARTY_NOTICES.md'

cache_dir.mkdir(parents=True, exist_ok=True)
license_dir.mkdir(parents=True, exist_ok=True)

def safe_name(value: str) -> str:
    return re.sub(r'[^A-Za-z0-9._-]+', '_', value).strip('_') or 'item'

def github_repo_from_url(url: str):
    parsed = urlparse(url)
    if parsed.netloc.lower() != 'github.com':
        return None
    parts = [segment for segment in parsed.path.split('/') if segment]
    if len(parts) < 2:
        return None
    owner = parts[0]
    repo = parts[1][:-4] if parts[1].endswith('.git') else parts[1]
    return owner, repo

def fetch_json(url: str):
    cache_key = hashlib.sha256(url.encode('utf-8')).hexdigest()
    cache_path = cache_dir / f'{cache_key}.json'
    if cache_path.exists():
        return json.loads(cache_path.read_text(encoding='utf-8')), None

    request = urllib.request.Request(
        url,
        headers={
            'User-Agent': 'InstechSandbox-Mobile-Compliance/1.0',
            'Accept': 'application/vnd.github+json',
        },
    )
    try:
        with urllib.request.urlopen(request, timeout=30) as response:
            body = response.read().decode('utf-8')
    except Exception as exc:  # noqa: BLE001
        return None, str(exc)

    cache_path.write_text(body, encoding='utf-8')
    return json.loads(body), None

rows = list(csv.DictReader(inventory_path.open('r', encoding='utf-8'), delimiter='\t'))

with metadata_path.open('w', encoding='utf-8', newline='') as handle:
    writer = csv.writer(handle, delimiter='\t', lineterminator='\n')
    writer.writerow(['identity', 'location', 'version', 'revision', 'branch', 'license_name', 'spdx', 'download_url', 'saved_file', 'status'])

    summary_lines = [
        '# iOS Third-Party Notices',
        '',
        'This file was generated automatically from Swift Package Manager metadata and the GitHub license API for package sources hosted on GitHub.',
        '',
        '| Identity | Source | Version | License | SPDX | Status |',
        '| --- | --- | --- | --- | --- | --- |',
    ]

    for row in rows:
        identity = row.get('identity', '')
        location = row.get('location', '')
        version = row.get('version', '')
        revision = row.get('revision', '')
        branch = row.get('branch', '')
        license_name = ''
        spdx = ''
        download_url = ''
        saved_file = ''
        status = 'unprocessed'

        repo_ref = github_repo_from_url(location)
        if repo_ref is None:
            status = 'non-github-source'
        else:
            owner, repo = repo_ref
            api_url = f'https://api.github.com/repos/{owner}/{repo}/license'
            payload, error = fetch_json(api_url)
            if error is not None:
                status = f'license-api-failed:{error}'
            elif isinstance(payload, dict):
                license_name = ((payload.get('license') or {}).get('name') or payload.get('name') or '').strip()
                spdx = ((payload.get('license') or {}).get('spdx_id') or '').strip()
                download_url = (payload.get('download_url') or '').strip()
                content = payload.get('content') or ''
                encoding = payload.get('encoding') or ''
                if content and encoding == 'base64':
                    file_name = f'{safe_name(identity)}__LICENSE.txt'
                    output_path = license_dir / file_name
                    output_path.write_bytes(base64.b64decode(content))
                    saved_file = f'license_texts/{file_name}'
                    status = 'harvested'
                else:
                    status = 'missing-license-content'

        writer.writerow([identity, location, version, revision, branch, license_name, spdx, download_url, saved_file, status])
        summary_lines.append(
            '| {} | {} | {} | {} | {} | {} |'.format(
                identity or '-',
                location or '-',
                version or branch or revision or '-',
                license_name or '-',
                spdx or '-',
                status or '-',
            )
        )

summary_lines.extend([
    '',
    'Generated files under `license_texts/` contain license texts fetched automatically from GitHub-hosted package sources where available.',
    'Any dependency marked as non-GitHub or failed still requires review before distribution.',
])
summary_path.write_text('\n'.join(summary_lines) + '\n', encoding='utf-8')
PY
}

write_release_record() {
  local platform=$1
  local repo=$2
  local bundle_dir=$3
  local record_file="$bundle_dir/RELEASE_RECORD.md"
  local remote_url
  local branch_name
  local commit_sha
  local commit_date
  local commit_summary

  remote_url=$(normalize_remote_url "$(git_remote_url "$repo")")
  branch_name=$(git_branch_name "$repo")
  commit_sha=$(git_commit_sha "$repo")
  commit_date=$(git_commit_date "$repo")
  commit_summary=$(git_short_summary "$repo")

  cat > "$record_file" <<EOF
# Mobile Tester Build Release Record

## Build Identity

- App: \
  ${platform}
- Build label: \
  $(basename "$bundle_dir")
- Distribution channel: \
  <fill this in>
- Build date: \
  ${commit_date}
- Built by: \
  InstechSandbox
- Proof-of-concept only: \
  yes

## Source Of Truth

- Source repository: \
  ${remote_url}
- Branch: \
  ${branch_name}
- Commit SHA: \
  ${commit_sha}
- Corresponding source visible to testers: \
  ${remote_url}/tree/${commit_sha}

## Modification Record

- Latest commit summary: \
  ${commit_summary}
- Modification summary:
  - <add release-specific summary>
  - <add release-specific summary>
- Modification date: \
  ${commit_date}
- Branding changes included: \
  <yes/no>
- Functional changes included: \
  <yes/no>
- Service rewiring included: \
  <yes/no>

## Notices Retained

- Repository LICENSE preserved: \
  yes
- Repository NOTICE preserved: \
  yes
- Existing file-header material preserved in source: \
  yes
- Additional modification notice published by InstechSandbox: \
  <fill this in>

## Third-Party Notice Bundle

- Dependency inventory generated: \
  yes
- Dependency inventory path: \
  third_party/dependency_inventory.tsv
- Third-party notice bundle path: \
  third_party/
- Release-specific reconciliation completed against shipped dependency set: \
  <yes/no>

## Distribution Notes

- Intended tester audience: \
  <fill this in>
- Production-ready: \
  no
- Official upstream release: \
  no

## Links

- Compliance guidance: \
  ${COMPLIANCE_GUIDE_REL}
- Dependency inventory baseline: \
  ${INVENTORY_GUIDE_REL}
EOF

  cp "$RELEASE_TEMPLATE" "$bundle_dir/RELEASE_RECORD_TEMPLATE.md"
}

write_bundle_readme() {
  local platform=$1
  local repo=$2
  local bundle_dir=$3
  local remote_url
  local commit_sha

  remote_url=$(normalize_remote_url "$(git_remote_url "$repo")")
  commit_sha=$(git_commit_sha "$repo")

  cat > "$bundle_dir/README.md" <<EOF
# Mobile Compliance Bundle

This bundle was generated for the ${platform} wallet proof-of-concept tester distribution.

It is intended to travel with the tester build or be published in a stable location referenced by the tester distribution message.

## Included Files

- RELEASE_RECORD.md: prefilled release record to complete before distribution
- RELEASE_RECORD_TEMPLATE.md: reusable blank template
- LICENSE.txt: repository license copied from the wallet repo
- NOTICE.txt: repository notice file copied from the wallet repo
- FILE_HEADER.txt: source header template copied from the wallet repo when present
- third_party/dependency_inventory.tsv: dependency inventory extracted from the platform manifest
- third_party/license_metadata.tsv: harvested license metadata for third-party dependencies
- third_party/THIRD_PARTY_NOTICES.md: generated markdown notice appendix
- third_party/license_texts/: fetched license texts where they could be resolved automatically
- third_party/README.md: instructions for final release reconciliation

## Source Snapshot

- Repository: ${remote_url}
- Commit: ${commit_sha}

## Important Limitation

The generated bundle automates dependency inventory extraction, license metadata harvesting, and license-text collection where available. It still does not prove the exact final runtime-linked set. Complete the reconciliation step in RELEASE_RECORD.md before distributing the build.
EOF
}

write_third_party_readme() {
  local platform=$1
  local bundle_dir=$2

  cat > "$bundle_dir/third_party/README.md" <<EOF
# Third-Party Notice Folder

This folder contains the extracted dependency inventory and harvested license material for the ${platform} wallet repo.

Before distributing the tester build:

1. review THIRD_PARTY_NOTICES.md and license_metadata.tsv
2. reconcile the generated inventory against the dependencies actually shipped in the archive or APK
3. add any extra release-specific third-party license texts or acknowledgements required by the shipped dependency set
4. record completion in ../RELEASE_RECORD.md

The repo-level LICENSE.txt and NOTICE.txt files at the root of the compliance bundle remain mandatory and should travel with this folder.
EOF
}

generate_bundle_for_platform() {
  local platform=$1
  local release_label=$2
  local repo
  local bundle_dir
  local inventory_file

  case "$platform" in
    android)
      repo="$WALLET_REPO"
      ;;
    ios)
      repo="$IOS_WALLET_REPO"
      ;;
    *)
      fail "Unsupported platform: $platform"
      ;;
  esac

  require_repo_artifacts "$repo"
  mkdir -p "$COMPLIANCE_OUTPUT_ROOT"

  bundle_dir="$COMPLIANCE_OUTPUT_ROOT/${release_label}-${platform}"
  rm -rf "$bundle_dir"
  mkdir -p "$bundle_dir/third_party"

  cp "$repo/LICENSE.txt" "$bundle_dir/LICENSE.txt"
  cp "$repo/NOTICE.txt" "$bundle_dir/NOTICE.txt"
  if [[ -f "$repo/FileHeader.txt" ]]; then
    cp "$repo/FileHeader.txt" "$bundle_dir/FILE_HEADER.txt"
  fi

  inventory_file="$bundle_dir/third_party/dependency_inventory.tsv"
  if [[ "$platform" == "android" ]]; then
    generate_android_inventory "$repo" "$inventory_file"
    harvest_android_notice_bundle "$inventory_file" "$bundle_dir/third_party" "$COMPLIANCE_CACHE_ROOT"
  else
    generate_ios_inventory "$repo" "$inventory_file"
    harvest_ios_notice_bundle "$inventory_file" "$bundle_dir/third_party" "$COMPLIANCE_CACHE_ROOT"
  fi

  write_release_record "$platform" "$repo" "$bundle_dir"
  write_bundle_readme "$platform" "$repo" "$bundle_dir"
  write_third_party_readme "$platform" "$bundle_dir"

  printf 'Generated %s compliance bundle at %s\n' "$platform" "$bundle_dir"
}

main() {
  local platform=${1:-}
  local release_label=${2:-}

  if [[ -z "$platform" || -z "$release_label" ]]; then
    usage
    exit 1
  fi

  case "$platform" in
    android|ios)
      generate_bundle_for_platform "$platform" "$release_label"
      ;;
    all)
      generate_bundle_for_platform android "$release_label"
      generate_bundle_for_platform ios "$release_label"
      ;;
    -h|--help|help)
      usage
      ;;
    *)
      usage
      exit 1
      ;;
  esac
}

main "$@"
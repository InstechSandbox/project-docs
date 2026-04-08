# Mobile App Distribution Compliance

## Purpose

This note records the operational compliance posture for distributing the Android and iOS wallet forks to a small set of proof-of-concept testers.

It is intended to make the project position explicit: InsTech wants to respect the upstream licenses, keep the corresponding source available, preserve notices, and avoid any implication that these tester builds are official production releases.

It is not legal advice.

## Current License Position

- `eudi-app-android-wallet-ui` is licensed under `EUPL-1.2` at repository level.
- `eudi-app-ios-wallet-ui` is licensed under `EUPL-1.2` at repository level.
- Both wallet repositories also carry `NOTICE.txt` material acknowledging Apache-2.0-origin files that were incorporated and modified upstream.
- Both wallet repositories include file-header material that should be preserved in source modifications.

For this project, that means the mobile apps can be modified and redistributed for proof-of-concept testing, but the redistribution must preserve the governing notices and keep the corresponding source available.

## What InsTech Is Doing To Respect The Licenses

For every distributed tester build, the intended compliance posture is:

1. Keep the corresponding source in the `InstechSandbox` fork available to recipients.
2. Preserve the upstream `LICENSE.txt`, `NOTICE.txt`, and existing source-file header materials.
3. Record that the build is modified by `InstechSandbox`, identify the source commit, and record the build or modification date.
4. Keep the mobile builds framed as proof-of-concept tester distributions, not official upstream or production releases.
5. Publish a third-party dependency notice record alongside the build.

This posture is designed to respect the current repo licenses rather than narrow or replace them.

To reduce manual handling risk, the repository now includes a shared generator script at `project-docs/scripts/generate-mobile-compliance-bundle.sh`. It creates a release-sidecar bundle containing copied repo notices, extracted dependency inventory, harvested third-party license metadata, fetched license texts where they can be resolved automatically, a generated markdown notice appendix, and a prefilled release record for Android, iOS, or both.

## Changes That Are Within Scope

The following categories of change are within the present proof-of-concept scope, subject to the release rules below:

- rewiring the apps to local or cloud issuer and verifier services for testing
- local trust and certificate adjustments needed for non-production interoperability
- functional proof-of-concept changes such as revised PID handling or testing-oriented flow changes
- branding adjustments such as colors, text, or InsTech-specific tester messaging

The main caution is not whether these changes are allowed in copyright terms. The main caution is that redistributed builds must preserve notices, keep source available, and avoid suggesting official endorsement by upstream maintainers, EU institutions, or other third parties.

## Required Release Record For Each Tester Build

Each Android APK distribution or iOS TestFlight build should have a corresponding release record or sidecar package that contains at least:

1. app name, build identifier, and build date
2. source repository URL and commit SHA
3. short summary of InsTech modifications
4. copy or link to the repository `LICENSE.txt`
5. copy or link to the repository `NOTICE.txt`
6. third-party dependency inventory and notice bundle for the shipped dependency set
7. statement that the build is proof-of-concept only and is not production-ready

For Android, this sidecar can travel with the APK distribution or be attached to the same GitHub release or delivery package.

For iOS, TestFlight does not naturally bundle text notice files with the app binary, so the notice record should be published in a durable location that testers can access, such as the relevant source repo release, a project-docs release artifact, or a stable project-docs document path.

A reusable blank release note is maintained in [Mobile App Release Record Template](Mobile_App_Release_Record_Template.md).

## Third-Party Notices

The repository-level `LICENSE.txt` and `NOTICE.txt` files are necessary, but they are not the whole compliance story for packaged mobile apps.

Both wallet apps depend on additional third-party packages. Their licenses may require attribution or notice handling when the packaged app is distributed.

At present, neither wallet repository appears to contain a repo-native automated third-party notice generator or a prebuilt bundled acknowledgements file for release artifacts. The safe operating posture is therefore:

1. preserve the repository-level notice files unchanged
2. keep a dependency inventory for each platform
3. build a release-specific notice bundle for the dependencies actually shipped

The current baseline inventories are documented in [Mobile Third-Party Notice Inventory](Mobile_Third_Party_Notice_Inventory.md).

The shared generator script now automates the creation of this sidecar bundle, including license metadata harvesting and notice appendix generation, but a final human reconciliation step is still required to confirm that the shipped runtime dependency set matches the generated inventory.

## Platform-Specific Release Rules

### Android Wallet

- Direct APK sharing to testers counts as redistribution.
- The APK release record should include the repo-level license and notice files plus the third-party notice inventory.
- If the dependency set changes materially, refresh the third-party inventory before distribution.

### iOS Wallet

- TestFlight distribution to external or internal testers should be treated as redistribution for notice and source-availability purposes.
- Because TestFlight is weak as a document-delivery channel, keep the notice bundle in a stable source-controlled or release-attached location and reference it in tester communications.
- If branding or naming diverges from upstream, make the forked proof-of-concept status explicit.

## Release Checklist

Use this checklist before distributing a mobile tester build:

1. Confirm the source commit is pushed to the corresponding `InstechSandbox` fork.
2. Confirm upstream `LICENSE.txt`, `NOTICE.txt`, and header materials remain intact.
3. Run `project-docs/scripts/generate-mobile-compliance-bundle.sh <android|ios|all> <release-label>`.
4. Prepare or refresh the release note describing the modification and date.
5. Review the generated `third_party/THIRD_PARTY_NOTICES.md`, `third_party/license_metadata.tsv`, and `third_party/license_texts/` contents.
6. Reconcile the generated dependency inventory against the dependencies actually shipped.
7. Publish the sidecar record or notice bundle in a durable location.
8. Distribute the tester build only after the source and notice record are available.

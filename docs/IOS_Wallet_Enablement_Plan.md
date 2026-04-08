# iOS Wallet Enablement Plan

## Purpose

Define the initial repo scope, build path, smoke-test target, and distribution preparation for enabling the iOS EUDI wallet in the InstechSandbox local stack.

## Current Scope

- Existing shared repos remain in scope: `.github`, `project-docs`, `eudi-app-android-wallet-ui`, `eudi-srv-issuer-oidc-py`, `eudi-srv-web-issuing-eudiw-py`, `eudi-srv-web-issuing-frontend-eudiw-py`, `av-srv-web-verifier-endpoint-23220-4-kt`, and `eudi-web-verifier`.
- Add the iOS wallet application repo: `eudi-app-ios-wallet-ui`.
- Treat `eudi-lib-ios-wallet-kit` as a tracked dependency first, not an active workstream repo, unless local source changes become necessary.

## Repository Strategy

- Desired long-term source of truth: `InstechSandbox/eudi-app-ios-wallet-ui`.
- Current local state: the `ios-wallet` workstream uses the `InstechSandbox/eudi-app-ios-wallet-ui` fork as `origin` and retains `eu-digital-identity-wallet/eudi-app-ios-wallet-ui` as `upstream`.
- Keep `origin` pointed at the InstechSandbox fork for isolated workstream changes and keep `upstream` pointed at `eu-digital-identity-wallet/eudi-app-ios-wallet-ui` for reference and sync.

## Initial Build Path

1. Install and validate a current stable Xcode toolchain.
2. Open `EudiReferenceWallet.xcodeproj` from `eudi-app-ios-wallet-ui`.
3. Confirm the documented schemes and variants for the app build.
4. Get a simulator build working first.
5. Get a signed device build working second.
6. Connect the iOS app to the existing local issuer and verifier stack.
7. Apply local self-signed certificate handling only as a documented local-only concession.

## Repeatable Build Goal

The iOS workstream should converge on the same engineering standard already used for the Android wallet work:

- explicit prerequisites
- deterministic local build commands where possible
- a documented simulator build path
- a documented device-signing path
- explicit local trust and certificate rules
- repeatable smoke checks

## Initial Smoke-Test Target

The first iOS smoke target should prove the following in order:

1. the app builds successfully for simulator
2. the app launches to the onboarding or PIN setup screen
3. the app can resolve the local issuer and verifier endpoints
4. a local issuance flow can complete
5. a same-device local verifier presentation can complete

## Distribution Preparation

- Use TestFlight as the intended tester distribution path.
- Set up Apple Developer Program membership, App Store Connect access, bundle identifiers, signing certificates, and provisioning profiles early.
- Treat external TestFlight beta review as a lead-time dependency rather than a final packaging step.
- Treat every tester build as a redistributed modified `EUPL-1.2` work: preserve upstream `LICENSE.txt`, `NOTICE.txt`, and header material, keep the corresponding fork source available, and publish a third-party notice record with the build.

## Documentation Rule For This Workstream

- Record build prerequisites, signing assumptions, local service configuration, trust handling, and smoke steps in `project-docs` as they are validated.
- Record the source commit, modification date, retained notices, and third-party dependency inventory used for each tester distribution.
- Tag a coordinated iOS-capable local baseline only after the build and smoke path are repeatable.

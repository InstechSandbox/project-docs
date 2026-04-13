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

## Reconnaissance Checkpoint 2026-04-05

### Standards And Scope Applied

- Applied constraints: `docs/EIDAS_ARF_Implementation_Brief.md` and `docs/AI_Working_Agreement.md`.
- Classification: this checkpoint is environment and build reconnaissance, not a protocol change.
- Affected roles: wallet build and local wallet integration only.

### Verified Local Environment Finding

- At the 2026-04-05 checkpoint, this Mac was configured with `xcode-select` pointing at `/Library/Developer/CommandLineTools`.
- At that checkpoint, `xcodebuild` could not run and failed with: `tool 'xcodebuild' requires Xcode, but active developer directory '/Library/Developer/CommandLineTools' is a command line tools instance`.
- At that checkpoint, no `Xcode*.app` bundle was found under `/Applications` or `~/Applications`.
- Result at that checkpoint: the iOS simulator and device build paths were not runnable until a full Xcode installation was present and selected.

### Verified Project Build Surface

- Shared schemes present in the repo:
	- `EUDI Wallet Dev`
	- `EUDI Wallet Demo`
- Both schemes build the `EudiWallet` app target with product name `EudiWallet.app`.
- Scheme to configuration mapping is currently:
	- `EUDI Wallet Dev` launch and test: `Debug Dev`
	- `EUDI Wallet Dev` archive and profile: `Release Dev`
	- `EUDI Wallet Demo` launch and test: `Debug Demo`
	- `EUDI Wallet Demo` archive and profile: `Release Demo`
- The project does not override `SYMROOT` or `CONFIGURATION_BUILD_DIR`, so build products should use standard Xcode `DerivedData` output unless a custom `-derivedDataPath` is supplied.

### Derived CLI Build Path To Validate Once Xcode Is Installed

- Simulator-first command shape:

```bash
cd "$CODE_ROOT/eudi-app-ios-wallet-ui"
xcodebuild \
	-project EudiReferenceWallet.xcodeproj \
	-scheme "EUDI Wallet Dev" \
	-configuration "Debug Dev" \
	-destination 'platform=iOS Simulator,name=iPhone 16 Pro' \
	-derivedDataPath .build/DerivedData \
	CODE_SIGNING_ALLOWED=NO \
	build
```

- Expected simulator artifact path for that command:

```bash
$CODE_ROOT/eudi-app-ios-wallet-ui/.build/DerivedData/Build/Products/Debug Dev-iphonesimulator/EudiWallet.app
```

- Device build command shape to validate after signing is configured:

```bash
cd "$CODE_ROOT/eudi-app-ios-wallet-ui"
xcodebuild \
	-project EudiReferenceWallet.xcodeproj \
	-scheme "EUDI Wallet Dev" \
	-configuration "Debug Dev" \
	-destination 'generic/platform=iOS' \
	-derivedDataPath .build/DerivedData \
	build
```

- Expected device artifact path for that command:

```bash
$CODE_ROOT/eudi-app-ios-wallet-ui/.build/DerivedData/Build/Products/Debug Dev-iphoneos/EudiWallet.app
```

- These commands are derived from the scheme and target metadata in the repository. They are not yet machine-validated because the required Xcode installation is missing.

### Validated Local Build Path 2026-04-07

- Full Xcode is now installed and selected through `xcode-select`.
- `project-docs/scripts/preflight-ios-wallet.sh` passes on this machine.
- `project-docs/scripts/build-ios-wallet-simulator.sh` completes successfully for `EUDI Wallet Dev` using `Debug Dev`.
- `project-docs/scripts/smoke-ios-wallet-simulator.sh` boots the resolved simulator, installs the built app, and launches bundle ID `eu.europa.ec.euidi.dev` successfully.
- Current validated simulator artifact path is:

```bash
$CODE_ROOT/eudi-app-ios-wallet-ui/.build/DerivedData/Build/Products/Debug Dev-iphonesimulator/EudiWallet.app
```

### Verified Signing Constraints

- The project is currently pinned to upstream manual signing settings for both the main app and the Identity Document Provider extension.
- Current project settings reference:
	- `DEVELOPMENT_TEAM = AZXQE7588Y`
	- manual `CODE_SIGN_STYLE`
	- upstream provisioning profile specifiers for all four Dev and Demo configurations
- Current bundle identifiers are split by variant:
	- main app Dev: `eu.europa.ec.euidi.dev`
	- main app Demo: `eu.europa.ec.euidi`
	- extension Dev: `eu.europa.ec.euidi.dev.EudiReferenceWalletIDProvider`
	- extension Demo: `eu.europa.ec.euidi.EudiReferenceWalletIDProvider`
- Current shared keychain group mapping for the extension is also variant-specific:
	- Dev: `eu.europa.ec.euidi.dev`
	- Demo: `eu.europa.ec.euidi`
- Practical implication: device builds will not be locally installable until the main app and extension are both moved to a locally owned Team ID, provisioning profile set, and matching entitlement-capable identifiers.

### Verified Local Issuer And Verifier Touchpoints

- The iOS wallet now exposes plist and xcconfig-backed overrides for a local issuer URL, local issuer client ID, local wallet attestation URL, and local trusted TLS hosts.
- The local issuer override should target the issuer frontend URL on `5003`, because the frontend publishes the local `credential_issuer` value used in credential offers.
- Local wallet attestation should target the auth server URL on `5001`, which serves the local wallet instance and wallet unit attestation endpoints.
- Local mdoc validation now also depends on a fresh local DS-under-IACA signer chain for POC use. The current shared approach is to generate that chain into ignored local files, let the issuer prefer the generated DS leaf, and let the wallets optionally load the generated local IACA root during local builds.
- When those local iOS overrides are enabled, the simulator browser path must also trust the shared runtime certificate; app-only `URLSession` trust overrides are not enough for the Safari or SFSafari browser handoff used during issuance.
- Simulator issuance must not use a keychain access group. Unsigned simulator builds do not carry the effective `application-identifier` and `keychain-access-groups` entitlements required by `KeychainAccess`, so the local simulator path now passes `nil` for the access group and falls back to the default app keychain while device builds keep the signed access-group path.
- Simulator issuance must also skip Identity Document Services registration. On iOS 26 simulators the `IdentityDocumentProviderRegistrationStore` path is entitlement-gated in the same unsigned local workflow, so simulator builds now resolve `DocumentRegistrationManagerNoOp` while device builds keep the real document-provider registration path.
- Simulator issuance must now avoid wallet-kit keychain persistence entirely. The unsigned simulator build still hits raw `SecItemAdd` inside wallet-kit document and secure-key storage even without an explicit access group, so the simulator bootstrap now injects in-memory document storage and an in-memory secure-key store; issued documents remain available only for the current app process, while device builds keep persistent keychain-backed wallet storage.
- `vpConfig` currently uses only `.x509SanDns` and `.x509Hash`; preregistered verifier client handling is optional and not enabled by default.
- Same-device deep-link schemes are declared in `Wallet/Wallet.plist` and already include the relevant OpenID4VP, credential-offer, and RQES schemes.
- Self-signed certificate handling is now limited to explicitly configured local hosts through `Modules/logic-api/Sources/Provider/NetworkSessionProvider.swift`; hosted paths still use default system validation.
- This local signer-chain generation is a lower-level trust compatibility step, not a change to wallet business logic or a claim of formal standards conformance. Its purpose is to make the local issuer and both reference wallets behave consistently for end-to-end POC testing.

### Next Validation Step

1. Install a full stable Xcode app.
2. Switch the active developer directory to that Xcode instance.
3. Re-run the derived simulator build command above and confirm the exact simulator artifact path.
4. Replace the upstream manual signing configuration with locally owned signing settings for both the app and extension.
5. Run the simulator build with `IOS_LOCAL_ISSUER_URL`, `IOS_LOCAL_WALLET_ATTESTATION_URL`, and `IOS_LOCAL_TRUSTED_HOSTS` set and confirm the app launches with those local settings compiled in.
6. Validate full local issuance and same-device verifier presentation against the existing local stack.

### Scripted Local Path Added

The shared `project-docs/scripts` workflow now includes:

1. `preflight-ios-wallet.sh`
2. `build-ios-wallet-simulator.sh`
3. `smoke-ios-wallet-simulator.sh`

Current intent of those scripts:

- fail fast when full Xcode is missing or `xcode-select` still points at Command Line Tools
- make the Xcode prerequisite explicit through `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` and `xcodebuild -version`
- build the wallet into a deterministic repo-local `DerivedData` path
- boot a named simulator, install the built app, and launch it by bundle identifier

Current limit of those scripts:

- they do not solve Apple Developer account setup
- they do not create provisioning profiles
- they do not make device builds work without locally owned signing material

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

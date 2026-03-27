# Local Deployment Notes

## Purpose

This document records the six-repository commit set that led to the current stable local working build for the InstechSandbox EUDI insurance readiness proof of concept.

It is intended to explain both:

- what changed between the upstream fork baseline and the current working state
- why those changes were necessary to make local end-to-end issuance and verification work reliably

## Scope

Repositories covered here:

- `eudi-app-android-wallet-ui`
- `eudi-srv-issuer-oidc-py`
- `eudi-srv-web-issuing-eudiw-py`
- `eudi-srv-web-issuing-frontend-eudiw-py`
- `av-srv-web-verifier-endpoint-23220-4-kt`
- `eudi-web-verifier`

The `project-docs` repository is documentation-only and is not part of the runtime stack.

## Analysis Method

For each implementation repository, the current fork head was compared with `upstream/main` using the merge base as the effective baseline for the current fork state.

The divergent commit set was then reviewed alongside the actual diffs and the validated local runtime notes gathered during the working-build exercise.

In practice, the divergent commit set is small. Most repositories contain:

- a temporary validation snapshot commit
- a validation/bootstrap refinement commit
- one final commit that codifies the stable local-working behavior or the smoke test used to verify it

## Stable Local Baseline

The stable local working build has been tagged and pushed in all six implementation repositories as:

- `local-e2e-baseline-2026-03-27`

### Baseline Tags And SHAs

| Repository | Tag | Commit SHA | Role In Local Stack |
| --- | --- | --- | --- |
| `eudi-app-android-wallet-ui` | `local-e2e-baseline-2026-03-27` | `b1cb7e19df0475c4f8f1caa92f8cde86dc63854f` | Android wallet used for issuance and verifier presentation |
| `eudi-srv-issuer-oidc-py` | `local-e2e-baseline-2026-03-27` | `c0d5dab53397ddf7504999a201b547de483fd0da` | local OAuth and authorization server |
| `eudi-srv-web-issuing-eudiw-py` | `local-e2e-baseline-2026-03-27` | `2e88a63ea61d9e71de25fc588fe92e0bc6cc98ad` | issuer backend |
| `eudi-srv-web-issuing-frontend-eudiw-py` | `local-e2e-baseline-2026-03-27` | `2c9ad0051e9970d8c7842c912784e5994a01a84c` | issuer frontend and metadata endpoint |
| `av-srv-web-verifier-endpoint-23220-4-kt` | `local-e2e-baseline-2026-03-27` | `02c5035a9e23378a8039102887a27ba0addf55cd` | verifier backend |
| `eudi-web-verifier` | `local-e2e-baseline-2026-03-27` | `c170d0e464e54b6a9ccf74c16707ef504c680926` | verifier UI |

## What Had To Change And Why

### 1. A Stable LAN Identity Was Needed Across The Stack

The local working build converged on a stable LAN host, `192.168.0.110`, so the phone, wallet, issuer services, and verifier could all resolve the same endpoints from the same network.

Why this mattered:

- `localhost` is not usable from a physical device
- changing IPs or mixing hosts breaks metadata, redirect URIs, and certificate trust assumptions
- the wallet and verifier flows both depend on durable, externally reachable HTTPS endpoints rather than process-local addresses

### 2. The Local Services Needed To Share A Certificate Story

The wallet is pinned to a bundled local certificate, so all relevant local HTTPS services had to present a certificate the wallet would actually trust.

Why this mattered:

- the Android wallet rejected local HTTPS calls when the served certificate did not match the bundled certificate material
- the verifier and issuer flows both rely on HTTPS, including metadata retrieval and request-object resolution
- a mismatch manifested as trust-anchor and certificate-path failures rather than functional protocol errors

The final working approach was:

- use a shared local certificate for the local auth, issuer, and frontend services where required
- update the wallet's bundled `backend_cert.pem` when the live local certificate changed
- make wallet-core request-object retrieval use a local-cert-aware client path instead of relying on the earlier client wiring

### 3. Metadata Had To Match The Real Local Topology

The issuer frontend and issuer backend needed local metadata overrides so the local environment could advertise the correct encryption and authorization-server values without mutating the canonical tracked metadata files.

Why this mattered:

- local metadata often needs LAN-specific URLs and keys that should not become the canonical repository default
- wallet acceptance depends on the metadata being internally consistent
- mismatches between advertised encryption metadata and live key material can cause credential-request or JWE decryption failures

The chosen pattern was:

- keep tracked metadata files canonical
- apply local metadata overrides from `support/metadata_overrides.json`
- make the frontend advertise the real authorization server instead of forcing the wallet to infer an incorrect one from the credential issuer URL

### 4. Issuance State Had To Survive The Real User Journey

The issuer backend needed to recover the issuing country and related state more defensively during the dynamic issuance flow.

Why this mattered:

- the happy-path assumption that all state would still be present in the session was not robust enough for the actual local runtime flow
- when country information was missing, downstream formatter logic could fail or generate inconsistent credential material

The final backend changes make the issuance flow fall back to submitted form data when session state is incomplete and persist that recovered country back into the session.

### 5. Deep Link Generation Had To Match Real Device Behavior

Both issuance and verifier testing needed a reliable way to generate fresh deep links and inject them into a physical Android device.

Why this mattered:

- both OpenID4VCI and OpenID4VP deep links are ephemeral and need to be regenerated for each attempt
- manual `adb shell am start -d ...` usage can silently truncate the URI at `&` if it is not quoted correctly
- that kind of truncation looks like a protocol bug from the wallet side even though the actual problem is shell argument handling

The final tooling added dedicated helper scripts that:

- fetch a live offer or request object
- build a launchable deep link
- optionally run the deep link through `adb`
- print a quoted shell-safe command for manual use

### 6. The Verifier Needed To Tolerate Repeated Request-Object Retrieval

The verifier backend had to allow the wallet to fetch the same `request_uri` more than once.

Why this mattered:

- the wallet may retrieve the request object repeatedly during its processing path
- the earlier verifier behavior assumed a stricter single-retrieval state progression
- repeated retrievals caused state-related failures even though the underlying request was still valid

The stable fix was to allow repeated retrieval from the already-retrieved state and regenerate the JAR without advancing the presentation state a second time.

### 7. Smoke Tests Were Added To Lock In The Working Baseline

The final step across the six repositories was to add or refine lightweight validation and smoke-test scripts.

Why this mattered:

- local success depended on several services starting correctly, not just compiling
- a green build was not enough to prove runtime readiness for the local E2E flow
- smoke tests make the working baseline repeatable and easier to diagnose when it regresses later

These smoke tests now verify things like:

- auth metadata can be served successfully
- wallet builds and local trust scaffolding are in place
- issuer metadata overrides are applied and local flows can be exercised
- verifier backend health and verifier UI shell startup both succeed

## Repository-By-Repository Summary

### eudi-app-android-wallet-ui

Fork-only commits from the current baseline:

- `2e5a51b5` - `chore: temporary validation snapshot`
- `868c6f81` - `chore: bootstrap wallet validation environment`
- `b1cb7e19` - `Support local wallet trust and add validation smoke test`

Key change:

- switched wallet-core request retrieval to a local-cert-aware client factory and updated the bundled backend certificate

Why it mattered:

- the phone had to trust the locally served verifier and issuer certificate chain for both issuance and OpenID4VP request-object retrieval
- the previous client wiring was not sufficient for the local self-signed verifier path

### eudi-srv-issuer-oidc-py

Fork-only commits from the current baseline:

- `80df7cf` - `chore: temporary validation snapshot`
- `84ba9ad` - `chore: adjust validation interpreter selection`
- `c0d5dab` - `Add auth server validation smoke test`

Key change:

- added a smoke test that instantiates the auth server and verifies `/.well-known/openid-configuration`

Why it mattered:

- the issuer flow depends on working discovery metadata and a live OAuth server, so this repository now has an explicit runtime validation step instead of relying on install success alone

### eudi-srv-web-issuing-eudiw-py

Fork-only commits from the current baseline:

- `3928b75` - `chore: temporary validation snapshot`
- `87b734b` - `chore: adjust validation interpreter selection`
- `2e88a63` - `Fix local issuance state and add metadata override support`

Key changes:

- added metadata override loading for local encryption metadata
- fixed country recovery in the dynamic issuance flow
- added a helper to generate and optionally launch issuance deep links

Why they mattered:

- the local issuer needed to advertise encryption metadata that matched the local runtime keys without changing canonical checked-in metadata
- issuance could fail when country state was missing late in the dynamic flow
- repeated device testing needed a reliable, current deep-link generator instead of manual reconstruction

### eudi-srv-web-issuing-frontend-eudiw-py

Fork-only commits from the current baseline:

- `22b4d8c` - `chore: temporary validation snapshot`
- `3b4532c` - `chore: adjust validation interpreter selection`
- `2c9ad00` - `Add frontend metadata override support and validation smoke test`

Key changes:

- added local metadata override loading
- kept local encryption metadata external to the canonical metadata file
- added a smoke-test-oriented validation step

Why they mattered:

- the frontend is the metadata surface consumed by the wallet, so local values needed to be correct without turning local-only settings into the permanent default

### av-srv-web-verifier-endpoint-23220-4-kt

Fork-only commits from the current baseline:

- `b4c7a44` - `chore: temporary validation snapshot`
- `1f4413d` - `chore: clarify verifier validation prerequisites`
- `e458830` - `chore: auto-detect Java 17 for validation`
- `09ae185` - `chore: harden verifier backend validation`
- `02c5035` - `Allow repeated request object retrieval and rename deeplink helper`

Key changes:

- allowed repeated retrieval of the same request object
- renamed and improved the verifier deep-link helper
- documented the need to preserve shell quoting when launching the deep link manually

Why they mattered:

- OpenID4VP testing on a physical phone exposed that the wallet may retrieve the same request more than once
- manual deep-link launching could fail for shell-quoting reasons that looked like verifier or wallet protocol errors

### eudi-web-verifier

Fork-only commits from the current baseline:

- `2130067` - `chore: temporary validation snapshot`
- `f2ee045` - `chore: stabilize verifier ui validation`
- `c170d0e` - `Add verifier UI validation smoke test`

Key change:

- added a disposable startup smoke test for the Angular verifier UI

Why it mattered:

- the verifier UI had to prove not only that it could build and test, but also that it could actually start and serve a page on a local port as part of the end-to-end flow

## Practical Definition Of The Working Local Build

At this baseline, the local environment is considered working when:

- the auth server is reachable over local HTTPS
- the issuer backend is reachable over local HTTPS
- the issuer frontend is reachable over local HTTPS
- the wallet trusts the local certificate presented by the relevant services
- the issuer metadata resolves correctly and advertises the correct authorization server
- a fresh issuance deep link can be generated and consumed by the device wallet
- a verifier deep link can be generated and used to present a locally issued credential

## Follow-On Guidance

If this baseline is extended later, keep the following approach:

- preserve canonical metadata in tracked source files
- isolate environment-specific values in explicit override files
- keep the org profile short and move operational depth into `project-docs`
- create a new coordinated six-repository baseline tag whenever the end-to-end local working state changes materially
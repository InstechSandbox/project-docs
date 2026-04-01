# Repo Gate Debt Backlog

## Purpose

Track the repo-native quality gates that were surfaced by the shared pre-push hooks so they can be fixed deliberately rather than while delivery work is in flight.

## Temporary Hook Bypass

- Shared hook commit to revert after these debt items are fixed: `dfe8b20` in the `.github` repository.
- Reversal intent: revert commit `dfe8b20` in `.github` once the wallet, issuer backend, verifier endpoint, and verifier UI gates are green again.

## Current Debt Items

### Wallet - Stabilize Gradle unit test suite

- Repository: `eudi-app-android-wallet-ui`
- Native gate: `./gradlew test`
- Current symptom: `dashboard-feature:testDemoDebugUnitTest` fails with 5 failing tests in `TestDocumentDetailsInteractor`.
- Why this matters: every normal push from this repo will fail until the suite is green or the gate is changed.
- Suggested ticket title: `Stabilize wallet Gradle unit tests for pre-push gate`
- Suggested ticket body: `The shared pre-push hook now runs ./gradlew test in eudi-app-android-wallet-ui. The current suite fails in dashboard-feature:testDemoDebugUnitTest with 5 failing TestDocumentDetailsInteractor tests. Triage whether the failures are flaky, environment-specific, or genuine regressions, then bring the default local test command back to green so normal pushes do not require a bypass.`

### Issuer Backend - Restore pytest baseline

- Repository: `eudi-srv-web-issuing-eudiw-py`
- Native gate: `.venv/bin/python -m pytest -q` when available, otherwise `python3 -m pytest -q`
- Current symptom: local pytest failures were surfaced in credential endpoint, dynamic field normalization, and revocation coverage.
- Why this matters: every normal push from this repo will fail until the pytest baseline is green or the gate is changed.
- Suggested ticket title: `Restore issuer backend pytest baseline for pre-push gate`
- Suggested ticket body: `The shared pre-push hook now runs pytest for eudi-srv-web-issuing-eudiw-py. Existing failures were surfaced in credential endpoint, dynamic field normalization, and revocation-related tests. Triage whether the failures reflect local environment drift, stale tests, or backend regressions, then restore a green pytest baseline for normal pushes.`

### Verifier Endpoint - Fix Gradle test task configuration

- Repository: `av-srv-web-verifier-endpoint-23220-4-kt`
- Native gate: `./gradlew test`
- Current symptom: Gradle fails while creating `:test` with `Type T not present` before the test suite runs.
- Why this matters: every normal push from this repo will fail until the build configuration issue is resolved or the gate is changed.
- Suggested ticket title: `Fix verifier endpoint Gradle test task configuration`
- Suggested ticket body: `The shared pre-push hook now runs ./gradlew test in av-srv-web-verifier-endpoint-23220-4-kt. The build currently fails before tests execute because Gradle cannot create :test and reports Type T not present. Triage plugin, toolchain, and test task configuration so the default test command becomes reliable for normal pushes.`

### Verifier UI - Reduce existing ESLint debt to restore push gate

- Repository: `eudi-web-verifier`
- Native gate: `npx ng lint` and `npx ng test --watch=false --browsers=ChromeHeadless`
- Current symptom: `npx ng lint` fails with widespread existing violations including indentation, quotes, semicolons, `@typescript-eslint/no-explicit-any`, and `prefer-standalone`.
- Why this matters: every normal push from this repo will fail until lint passes, the rule set is intentionally adjusted, or the gate is changed.
- Suggested ticket title: `Restore verifier UI lint baseline for pre-push gate`
- Suggested ticket body: `The shared pre-push hook now runs Angular lint and headless tests in eudi-web-verifier. Lint currently fails across existing files with formatting and Angular-eslint rule violations, which blocks normal pushes even for unrelated changes. Decide whether to fix the files incrementally, tune the lint profile intentionally, or split the gate into staged and legacy debt phases, then restore a green baseline.`

## Working Rule

- The current temporary bypass lives in `.github` commit `dfe8b20` and should remain temporary.
- Do not normalize bypasses for feature work.

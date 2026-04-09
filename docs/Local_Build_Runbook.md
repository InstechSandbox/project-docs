# Local Build Runbook

This runbook is for a quick, credible end-to-end local build and runtime flow across the six components.

It is intentionally thin.

The orchestration scripts in `project-docs/scripts` do not replace repository-local build logic. They wrap the existing repo-native commands so the same responsibilities can later move into GitHub Actions or cloud deployment automation without throwing this work away.

The examples below use `$CODE_ROOT` for the parent directory that contains the sibling repositories. If you run the wrappers from `project-docs/scripts`, they derive that automatically unless you override `CODE_ROOT` in `scripts/local-demo.env`.

## Quickstart

If you want the shortest operator path, use this exact sequence.

Build and runtime path:

```bash
cd "$CODE_ROOT/project-docs/scripts"
./bootstrap-local-python-venvs.sh
./build-local-all.sh
./start-local-all.sh
./smoke-local-all.sh
./install-wallet-demo-apk.sh --fresh
```

`./smoke-local-all.sh` is intentionally before `./install-wallet-demo-apk.sh --fresh`. The smoke step validates the local services and verifier stack first, then the APK install step prepares the phone for issuance and verification.

Normal `./build-local-all.sh` and `./start-local-all.sh` runs do not rewrite the wallet app's embedded `backend_cert.pem`. Wallet trust material only changes when you run an explicit cert-rotation step.

You do not need to run `./stop-local-all.sh` before `./start-local-all.sh`. The start wrapper already performs a quiet stop first so it can restart the stack cleanly.

If you only changed Python service configuration, certificates, or wrapper wiring, you do not need a full clean rebuild or APK reinstall. Use this lighter recovery path:

```bash
cd "$CODE_ROOT/project-docs/scripts"
./start-local-all.sh
./smoke-local-all.sh
```

Use a full clean rebuild plus fresh APK install only when you want maximum confidence, when the wallet APK changed, or when you want to prove the entire stack can be rebuilt from scratch.

If you want a heavier rebuild for maximum confidence, use this instead of `./build-local-all.sh`:

```bash
cd "$CODE_ROOT/project-docs/scripts"
./build-local-all-clean.sh
./start-local-all.sh
./smoke-local-all.sh
./install-wallet-demo-apk.sh --fresh
```

Functional verification path:

```bash
cd "$CODE_ROOT/project-docs/scripts"
./run-issuance-demo.sh
./run-verification-demo.sh
```

`./run-issuance-demo.sh` now defaults to `eu.europa.ec.eudi.pid_vc_sd_jwt` so the automated local issuance path matches the Irish Life verifier request. Override `CREDENTIAL_CONFIGURATION_ID` only when you intentionally want to test a different credential format.

Logs:

```bash
cd "$CODE_ROOT/project-docs/.local/logs"
tail -F auth-server.log issuer-backend.log issuer-frontend.log
```

## Goal

Confirm that:

1. the local stack can be rebuilt in a repeatable way
2. the local runtime can be started predictably
3. a fresh wallet APK can be installed
4. issuance works
5. verification works

## Component Grouping

For orientation, treat the six components as three groups:

1. Wallet build
   - `eudi-app-android-wallet-ui`
2. Python runtime services
   - `eudi-srv-issuer-oidc-py`
   - `eudi-srv-web-issuing-eudiw-py`
   - `eudi-srv-web-issuing-frontend-eudiw-py`
3. Docker verifier stack
   - `av-srv-web-verifier-endpoint-23220-4-kt`
   - `eudi-web-verifier`
   - `haproxy`

## Files Added For This Workflow

- `scripts/local-demo.env.example`
- `scripts/build-local-all.sh`
- `scripts/build-local-all-clean.sh`
- `scripts/start-local-all.sh`
- `scripts/stop-local-all.sh`
- `scripts/smoke-local-all.sh`
- `scripts/install-wallet-demo-apk.sh`
- `scripts/run-issuance-demo.sh`
- `scripts/run-verification-demo.sh`

These should stay as wrappers around repo-level build and launch entry points.

## One-Time Setup

1. Copy `scripts/local-demo.env.example` to `scripts/local-demo.env` if you need to override local paths or other local settings.
2. Install one of the supported local Python versions: `python3.11` is preferred because it matches the current Python Dockerfiles; `python3.10` and `python3.9` remain acceptable fallbacks.
3. Build or refresh the local Python service virtual environments with:

```bash
cd "$CODE_ROOT/project-docs/scripts"
./bootstrap-local-python-venvs.sh
```

This wrapper rebuilds `.venv` for the auth server, issuer backend, and issuer frontend using a supported interpreter. It prefers `python3.11`, then `python3.10`, then `python3.9`, and refuses unsupported minors such as `python3.14`.

If you are working from linked worktrees and a repo-local `.env`, JWKS file, cert bundle, or signing key is missing, copy or recreate that local-only material before the first build. The wrappers do not invent all repo-local secrets or signing assets automatically.

If the issuer backend local checkout does not already contain the local Utopia PID signer assets needed for mdoc issuance, set `LOCAL_UTOPIA_SIGNER_SOURCE_DIR` in `scripts/local-demo.env` to a local seed directory that contains:

```bash
privKey/PID-DS-0001_UT.pem
cert/PID-DS-0001_UT_cert.der
cert/PID-DS-0001_UT_cert.pem
```

The issuer backend bootstrap uses that seed directory to populate the local signer files before startup. Without those assets, the issuance flow will fail after form submission when the backend tries to build the PID mdoc.

If Gradle cannot find the Android SDK automatically, set `ANDROID_SDK_DIR` in `scripts/local-demo.env`. The shared wrappers will mirror that into the wallet `local.properties` file as `sdk.dir` during the local build flow.

## To Avoid Drift In Practice

Use these rules as the default operator path:

1. Run `./bootstrap-local-python-venvs.sh` before the first local build on a machine, and again whenever your local Python installation changes.
2. Treat `python3.11` as the default local target because it is the closest current match to the Python container packaging used by the issuer services.
3. Use `python3.10` or `python3.9` only when `python3.11` is unavailable or when you are deliberately checking fallback behaviour.
4. Do not work around a broken local `.venv` by changing repo code, changing cloud deployment scripts, or pinning ad hoc package versions first; rebuild the `.venv` from the shared bootstrap wrapper and re-run the local build path.
5. If the shared wrappers report an unsupported Python minor inside `.venv`, treat that as environment drift, not as a product bug.
6. If the wallet build fails because Gradle cannot find the Android SDK, treat that as local machine setup drift and fix it through `ANDROID_SDK_DIR`, `ANDROID_SDK_ROOT`, or `ANDROID_HOME` rather than by editing Gradle build logic.

7. Confirm the shared local certificate and key paths are correct.
   - normal start runs refresh the shared runtime certificate for the local services when needed, but they do not update the wallet PEM by default
   - `./build-local-all.sh` and `./build-local-all-clean.sh` sync the shared cert into the wallet source before compiling the APK
   - if you rotate the shared cert outside those build wrappers, run `./refresh-local-certs.sh --sync-wallet-cert`, then rebuild and install the wallet APK
8. Confirm Docker Desktop is running if that is your local Docker engine.
9. Check the current LAN IP with:

```bash
ipconfig getifaddr en0 || ipconfig getifaddr en1
```

The wrappers now auto-detect this Mac's LAN IP by default. You only need to uncomment `PUBLIC_HOST` and `VERIFIER_PUBLIC_HOST` in `scripts/local-demo.env` if you want to force a manual override.

1. Confirm your Android SDK `adb` path is correct if you want the runbook to show device status.
2. Set `ANDROID_SERIAL` in `scripts/local-demo.env` if you want deterministic device targeting for install and deep-link steps.

Docker Desktop is fine for this workflow, but use the runbook commands as the source of truth for starting and checking the verifier stack. Docker Desktop is useful as a visual status view, not as a replacement for the scripted `docker compose` flow.

`PUBLIC_HOST` is the LAN IP address of this Mac, not the router IP. It can change if your DHCP lease changes, if you switch interfaces, if the network reassigns addresses, or if you move between wired and wireless connections.

If you need to stop everything explicitly, use:

```bash
cd "$CODE_ROOT/project-docs/scripts"
./stop-local-all.sh
```

Use that explicit stop when you want to tear the local stack down at the end, or when you want a manual reset before investigating logs. It is not required before the normal `./start-local-all.sh` path.

## Irish Life Email And Customer Surface Settings

The Irish Life New Business verifier flow now depends on two verifier-backend settings when you want the full agent-plus-customer demo to work end to end.

Required verifier settings for the customer surface and email flow:

- `verifier.irishlife.customerBaseUrl`
- `verifier.mail.from`

Required SMTP settings for real email sending:

- `spring.mail.host`
- `spring.mail.port`
- `spring.mail.username`
- `spring.mail.password`
- any required SMTP auth or TLS properties

For local Angular development, `verifier.irishlife.customerBaseUrl` should normally point at the frontend dev server, for example:

```properties
verifier.irishlife.customerBaseUrl=http://localhost:4200
verifier.mail.from=no-reply@example.com
spring.mail.host=smtp.example.com
spring.mail.port=587
spring.mail.username=demo-user
spring.mail.password=demo-password
spring.mail.properties.mail.smtp.auth=true
spring.mail.properties.mail.smtp.starttls.enable=true
```

The verifier UI now uses same-origin API calls for `/ui`, `/wallet`, and `/utilities` instead of a hardcoded `http://localhost:8080` base URL. That means the Docker-served HTTPS UI can talk to the verifier backend without mixed-content problems, and `npm start` continues to work through the Angular dev-server proxy.

For the local Docker verifier path started by `scripts/start-local-all.sh` or `av-srv-web-verifier-endpoint-23220-4-kt/scripts/start-local-verifier.sh`, the customer surface URL is now derived automatically from the active verifier public host. On a LAN or hotspot IP change, restarting the verifier stack is enough to refresh Irish Life customer links and same-device return URLs.

The Android wallet also bakes `LOCAL_VERIFIER_API` and `LOCAL_ISSUER_URL` into its generated `BuildConfig` from `localDemoHost`. If the Mac's LAN IP changes and you only restart the local services, verification can still fail before the consent screen because the installed APK is still pre-registered against the old verifier URL. `scripts/build-local-all.sh` and `scripts/build-local-all-clean.sh` already resync `local.properties` before rebuilding; `scripts/install-wallet-demo-apk.sh` now also refuses to install a stale APK so the mismatch is caught before device testing.

For local same-device troubleshooting, keep `response_type=vp_token` present on both the outer `eudi-openid4vp://...` deep link and the signed request object served from `request_uri`. Check both the verifier backend response and any verifier UI fallback builder that reconstructs `authorization_request_uri`, because a missing outer `response_type` in either path still triggers wallet-side `MissingResponseType` before consent.

If SMTP is not configured, the verifier backend will still expose the case flow and wallet journey, but invite and completion emails will be reported as not sent.

For local runs, the default placeholder host `smtp.example.com` is now treated as email-disabled on purpose. That prevents the Irish Life `Create case and send invite` action from blocking on a fake SMTP connection while still letting the case move to `INVITE_SENT` and expose the customer portal URL.

The Irish Life agent surface now shows which step is active during case creation versus invite sending, and it clears the spinner locally if the browser waits too long for either step. If the page reports that it stopped waiting, use `Refresh case` before retrying so you can tell whether the backend already created the case or issued the invite.

For the Irish Life SD-JWT PID flow, the local issuer frontend must advertise `eu.europa.ec.eudi.pid_vc_sd_jwt` in `CREDENTIALS_SUPPORTED`. The current local wrapper does this automatically so wallet discovery stays consistent with the verifier request.

For the Irish Life proof-of-address happy path, use the local `FC` dynamic PID form rather than the reduced one-step Utopia form description. The current local issuer backend sends optional PID address claims to the frontend, and the dynamic form exposes them behind `Add Optional Attributes`.

For the simplest end-to-end address proof, add the optional `Address` fields during PID issuance and populate at least:

1. `street_address`
2. `locality`
3. `region`
4. `postal_code`

Example values:

1. `street_address = 1 Main Street`
2. `locality = Dublin`
3. `region = Leinster`
4. `postal_code = D02 XY56`

Then enter the Irish Life New Business `Current address` exactly as:

`1 Main Street, Dublin, Leinster, D02 XY56`

The verifier now requests those structured PID address claims and reconstructs the comparison string in that same comma-separated order. If the issuer form also exposes `Formatted`, you can set it to the same joined value above, but it is not required for the local verifier path.

In the current dynamic issuer UI, the optional address block is rendered from claim keys, so the visible labels appear in this order under `Address`:

1. `Street Address`
2. `Locality`
3. `Region`
4. `Postal Code`
5. `Country`
6. `Formatted`
7. `House Number`

For the local verifier path, only the first four are needed. `Country` can still be entered in the issuer form, but the Irish Life verifier no longer depends on it being disclosed for the address comparison. The verifier comparison now tolerates punctuation-only differences and whitespace-only differences inside the final address string, including cases like `D02 XY56` versus `D02XY56`, but it still expects the same underlying address values.

Once you have completed one successful issuance and Irish Life proof with this address shape, you do not need to rerun the happy path unless you change the verifier request, the issuer address fields, the local host/cert material, or the wallet APK again. Re-running is only useful as a regression check after further changes.

The shared local runtime certificate must advertise SAN URI entries for the local HTTPS service identities, especially `ISSUER_URL`. The verifier's SD-JWT issuer-certificate check does not treat a bare IP SAN as equivalent to the issuer identifier `https://host:5002`, so a cert that only contains `IP:...` and `DNS:localhost` can still let issuance succeed but fail post-share verification with `IssuerCertificateIsNotTrusted`.

The SD-JWT signer certificate under `eudi-srv-web-issuing-eudiw-py/local/cert/PID-DS-0001_UT_cert.{pem,der}` is a separate certificate from the shared runtime TLS cert. `scripts/refresh-local-certs.sh` now validates that signer certificate against the existing `PID-DS-0001_UT.pem` private key and regenerates the PEM and DER files with `URI:$ISSUER_URL` in SAN when needed. After that signer cert changes, restart the issuer backend and reissue the credential before retrying proof.

The Irish Life verifier case flow does not rely on the manual trusted-issuer UI control. For local PID verification, `av-srv-web-verifier-endpoint-23220-4-kt/scripts/start-local-verifier.sh` now mounts `eudi-srv-web-issuing-eudiw-py/local/cert/PID-DS-0001_UT_cert.pem` into the verifier container and injects it as the `issuer_chain` for Irish Life proof transactions. If that signer certificate changes, restart the verifier stack as well so new transactions carry the updated chain.

## Optional Working Layout

If you want to keep the workflow visible while building and testing, use no more than four panes.

Recommended layout:

1. Pane 1: orchestration terminal
2. Pane 2: service log terminal
3. Pane 3: Docker status terminal
4. Pane 4: device or phone mirror terminal/window

If you are using a mirrored phone, it should show:

1. fresh APK installation
2. credential issuance
3. credential verification

Useful parallel pane commands during build and runtime verification:

1. Pane 1: orchestration control

```bash
cd "$CODE_ROOT/project-docs/scripts"
```

1. Pane 2: wrapped Python service logs

```bash
cd "$CODE_ROOT/project-docs/.local/logs"
tail -F auth-server.log issuer-backend.log issuer-frontend.log
```

1. Pane 3: verifier Docker status

```bash
cd "$CODE_ROOT/av-srv-web-verifier-endpoint-23220-4-kt"
docker compose -f docker/docker-compose.local.yml ps
```

If Docker Desktop is open, you can also leave it visible as a secondary confidence signal, but keep the terminal command above as the primary check because it is reproducible and matches the wrapper scripts.

If `verifier-haproxy` is not listed there, that does not mean the command is wrong. It usually means HAProxy exited, because `docker compose ... ps` only shows running containers.

If you are troubleshooting why a service is missing, use:

```bash
cd "$CODE_ROOT/av-srv-web-verifier-endpoint-23220-4-kt"
docker compose -f docker/docker-compose.local.yml ps -a
```

`docker compose ... ps` shows only running containers. `docker compose ... ps -a` also shows exited containers such as a failed `verifier-haproxy`.

1. Pane 4: device targeting and install

```bash
"$ADB_BIN" -s "$ANDROID_SERIAL" devices -l
```

Open the phone mirror once you move from build and runtime verification into install, issuance, and verification.

## Execution Sequence

### 1. Build

From `project-docs/scripts` run:

```bash
./build-local-all.sh
```

If you want a visibly heavier rebuild, run this instead:

```bash
./build-local-all-clean.sh
```

What this confirms:

- wallet APK is rebuilt locally
- verifier Docker images are rebuilt locally
- Python service environments are present and launchable

What this does not do by default:

- it does not rotate the wallet app's embedded `backend_cert.pem`
- if you intentionally change wallet trust material, run `./refresh-local-certs.sh --sync-wallet-cert` before rebuilding and reinstalling the APK

If `build-local-all.sh` or `start-local-all.sh` fails in preflight with an unsupported Python minor version inside `.venv`, rerun `./bootstrap-local-python-venvs.sh` before retrying.

`build-local-all.sh` is the faster incremental path. `build-local-all-clean.sh` forces a heavier wallet rebuild and a no-cache Docker rebuild.

The wallet APK artifact used by this flow is expected at:

- `$CODE_ROOT/eudi-app-android-wallet-ui/app/build/outputs/apk/demo/debug/app-demo-debug.apk`

### 2. Runtime

Run:

```bash
./start-local-all.sh
./smoke-local-all.sh
```

This runtime smoke is a stack-health check, not a wallet-install step. Run it before touching the phone so service and verifier failures are caught before APK install, issuance, or verification.

What this confirms:

- auth service is up on `5001`
- issuer backend is up on `5002`
- issuer frontend is up on `5003`
- verifier stack is up via Docker and exposed publicly over `443`
- the configured `ANDROID_SERIAL` status is reported when one is set

At this point the service logs should exist under `$CODE_ROOT/project-docs/.local/logs`, so the log pane command above should stream cleanly.

By default, the ADB check is informational. If you want the smoke run to fail when the configured Android target is unavailable, set `SMOKE_REQUIRE_ANDROID_DEVICE=true` in `scripts/local-demo.env`.

The runtime summary now prints both the detected LAN IP and the source used for the host selection. If a service URL is unreachable even though the runtime summary looks correct, compare that summary with the LAN IP command above and then check `docker compose ... ps -a` for exited containers.

### 3. Fresh APK Installation

```bash
./install-wallet-demo-apk.sh
```

If the phone already has a higher-version wallet package installed, use:

```bash
./install-wallet-demo-apk.sh --fresh
```

`--fresh` will uninstall the package that matches the APK application ID before reinstalling it.

You do not need `--fresh` after Python-only backend or frontend fixes. Use it when the wallet APK changed, when Android refuses a downgrade, or when you want the cleanest possible device state.

The install wrapper also checks that the wallet's embedded local PEM still matches the current shared runtime certificate. If it fails there, sync the cert into the wallet source and rebuild before retrying the install.

If you explicitly rotate wallet trust material with `./refresh-local-certs.sh --sync-wallet-cert`, the wallet APK has changed and should be reinstalled on the phone before wallet-based testing.

Alternative if you want Gradle to build and install in one step:

```bash
cd "$CODE_ROOT/eudi-app-android-wallet-ui"
./gradlew buildAndInstallDemoDebug --console=plain
```

The wrapper is the cleaner path because it reuses `ADB_BIN`, `ANDROID_SERIAL`, and `APK_PATH` from `scripts/local-demo.env` and handles downgrade collisions explicitly.

### 4. Issuance

Trigger issuance using the wrapper:

```bash
./run-issuance-demo.sh
```

The wrapper passes `ADB_BIN`, `ANDROID_SERIAL`, and `ISSUER_URL` through to the repo-native helper.

### 5. Verification

Trigger verification using the wrapper:

```bash
./run-verification-demo.sh
```

This confirms that the issued credential can be presented to the local verifier stack.

## Why This Is Not Throwaway

This orchestration is intentionally limited to:

- local path wiring
- repo sequencing
- health checks
- log and pid handling

It avoids duplicating component-specific build logic.

That means later evolution can be:

1. repo-level GitHub Actions build jobs per repository
2. a higher-level orchestration workflow that calls those repo jobs
3. a cloud deployment pipeline that reuses the same environment variables and health checks

## Troubleshooting Notes

### Docker Service Missing

If `verifier-haproxy` does not appear in `docker compose -f docker/docker-compose.local.yml ps`, it may have exited during startup.

Use:

```bash
cd "$CODE_ROOT/av-srv-web-verifier-endpoint-23220-4-kt"
docker compose -f docker/docker-compose.local.yml ps -a
docker logs verifier-haproxy | tail -n 80
```

### Host IP Changed

If the Mac's LAN IP changes, the wrappers now pick it up automatically by default. Restart the stack:

```bash
cd "$CODE_ROOT/project-docs/scripts"
./stop-local-all.sh
./start-local-all.sh
./smoke-local-all.sh
```

Only edit `scripts/local-demo.env` if you intentionally want to force a manual `PUBLIC_HOST` or `VERIFIER_PUBLIC_HOST` override.

### Issuer Frontend Looks Wrong

If the issuer credential choices differ from the known-good local flow, or the country-selection page renders without the expected sizing, regenerate the frontend env and restart the frontend.

The local frontend config must write concrete `SERVICE_URL`, `ISSUER_URL`, and `OAUTH_URL` values into `.env`, and the default demo credential list should include `eu.europa.ec.eudi.pid_vc_sd_jwt` alongside the mdoc options.

If the Tailwind-based issuer pages render unstyled after a clean checkout or rebuild, the local frontend startup path now rebuilds `app/static/css/tailwind.css` automatically. If that still fails, run `npm install --no-package-lock` and `npm run build` inside `eudi-srv-web-issuing-frontend-eudiw-py` and then restart only the issuer frontend.

If issuance fails after the form step with the generic backend error page, check that `eudi-srv-web-issuing-eudiw-py/local/privKey/nonce_rsa2048.pem` and `credential_request_ec.pem` exist. The local backend patch helper now generates those files automatically when missing.

## Next Evolution

When the build system grows up, keep this split:

1. repository-local build logic stays inside each implementation repo
2. cross-repo orchestration stays outside the implementation repos
3. local and cloud should share the same service naming, URLs, and health-check model where possible

That is the reason these wrapper scripts live in `project-docs` rather than inside one of the six implementation repositories.

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
./install-wallet-local-apk.sh --fresh
```

`./smoke-local-all.sh` is intentionally before `./install-wallet-local-apk.sh --fresh`. The smoke step validates the local services and verifier stack first, then the APK install step prepares the phone for issuance and verification.

For local Android installation, the repo-native command is `./gradlew buildAndInstallDevDebug`. The shared wrapper `./install-wallet-local-apk.sh --fresh` now runs that command for you after checking local certificates, LAN host settings, and optional uninstall.

Normal `./build-local-all.sh` and `./start-local-all.sh` runs do not rewrite the wallet app's embedded `backend_cert.pem`. Wallet trust material only changes when you run an explicit cert-rotation step.

You do not need to run `./stop-local-all.sh` before `./start-local-all.sh`. The start wrapper already performs a quiet stop first so it can restart the stack cleanly.

If you only changed Python service configuration, certificates, or wrapper wiring, you do not need a full clean rebuild or APK reinstall. Use this lighter recovery path:

```bash
cd "$CODE_ROOT/project-docs/scripts"
./start-local-all.sh
./smoke-local-all.sh
```

`./smoke-local-all.sh` now also verifies that the live auth, issuer backend, and issuer frontend endpoints are serving the same TLS certificate file that this worktree expects. That matters when multiple sibling worktrees can start local stacks on the same ports.

Use a full clean rebuild plus fresh APK install only when you want maximum confidence, when the wallet APK changed, or when you want to prove the entire stack can be rebuilt from scratch.

If you want a heavier rebuild for maximum confidence, use this instead of `./build-local-all.sh`:

```bash
cd "$CODE_ROOT/project-docs/scripts"
./build-local-all-clean.sh
./start-local-all.sh
./smoke-local-all.sh
./install-wallet-local-apk.sh --fresh
```

Functional verification path:

```bash
cd "$CODE_ROOT/project-docs/scripts"
./run-issuance-demo.sh
./run-verification-demo.sh
./run-ios-verification-deeplink.sh
```

`./run-issuance-demo.sh` now defaults to `eu.europa.ec.eudi.pid_vc_sd_jwt` so the automated local issuance path matches the Irish Life verifier request. Override `CREDENTIAL_CONFIGURATION_ID` only when you intentionally want to test a different credential format.

`./run-ios-verification-deeplink.sh` now asks the local verifier for JWT PID `dc+sd-jwt` by default because that is the most reliable current iOS simulator proof path. Set `PID_PRESENTATION_FORMAT=mdoc` to probe the mdoc path, or `PID_PRESENTATION_FORMAT=dual` to ask for either representation when you explicitly want to test mixed local wallet state.

The verifier deeplink generators must target the same TLS endpoint as the local verifier smoke path: `VERIFIER_PUBLIC_URL` if explicitly set, otherwise `https://${VERIFIER_PUBLIC_HOST:-<lan-ip>}:4443` unless `VERIFIER_TLS_HOST_PORT=443`. If a generated `request_uri` drops `:4443` in the shared local stack, iOS may surface that as a misleading DCQL error with a certificate warning instead of a verifier URL misconfiguration.

The current local iOS same-device verifier path also assumes the verifier request object is signed with `ES256`. The local verifier backend already defaults to `verifier.jar.signing.algorithm=ES256`; if you change that for local testing, keep the iOS wallet's pre-registered verifier configuration aligned or the wallet will fail request resolution before DCQL handling.

For simulator proof runs that enter the `EudiReferenceWalletIDProvider` authorization flow, the extension must derive the same main-app bundle identifier as the wallet when computing document-storage and quick-PIN keychain service names. If the extension falls back to its own bundle id, proof-time PIN validation can report `Invalid pin` even when the entered value is correct because the extension is reading an empty keychain namespace.

The shared unsigned simulator build path also does not carry the Apple keychain entitlements required for quick-PIN storage. In that local path, simulator-only quick-PIN persistence must use a non-keychain local store. Do not treat simulator `Invalid pin` errors as proof that the entered digits are wrong until you confirm the build actually has a working PIN persistence backend.

Logs:

```bash
cd "$CODE_ROOT/project-docs/.local/logs"
tail -F auth-server.log issuer-backend.log issuer-frontend.log
```

iOS wallet preflight, build, and simulator smoke path:

```bash
cd "$CODE_ROOT/project-docs/scripts"
./preflight-ios-wallet.sh
./build-ios-wallet-simulator.sh
./smoke-ios-wallet-simulator.sh
```

If iOS browser-based issuance still shows a private-connection warning after simulator trust import, treat that first as a live-cert alignment problem, not as an app build problem. The simulator smoke path now checks that the configured local auth and issuer endpoints are serving the same certificate fingerprint as `SHARED_CERT_FILE` before importing the cert into the simulator.

For local mdoc issuance, generate a fresh local IACA plus DS chain before rebuilding the wallets or issuer runtime:

```bash
cd "$CODE_ROOT/project-docs/scripts"
./generate-local-mdoc-signer-chain.sh
```

The script writes fresh private signer material only into the issuer repo's ignored `local/` paths and writes the matching public IACA root into ignored wallet-local resource paths so Android and iOS can trust the same local mdoc chain without committing machine-specific trust artifacts.

What this local mdoc signer chain means:

- It is a local POC trust model for interoperability testing, not production PKI.
- It exists so the reference issuer and both reference wallets validate the same local signer shape during end-to-end testing.
- It intentionally moves the local demo closer to the trust-chain structure expected by real mdoc validation instead of relying on a self-issued shortcut that one wallet may tolerate and another may reject.
- It does not by itself claim formal eIDAS conformity, certification, or production readiness.

For client-facing POC use, this is the preferred local approach because it keeps verifier, issuer, and wallet testing aligned on one explicit signer-chain model. Treat it as standards-aligned local plumbing, not as a substitute for production trust onboarding.

These iOS scripts assume a full Xcode installation is present and selected through `xcode-select`. They do not install Xcode, create Apple Developer assets, or configure provisioning profiles for device builds.

## Goal

Confirm that:

1. the local stack can be rebuilt in a repeatable way
2. the local runtime can be started predictably
3. a fresh wallet APK can be installed
4. issuance works
5. verification works

For the iOS wallet path, the current goal is narrower until Apple signing is validated:

1. Xcode preflight passes
2. the wallet builds for simulator into a deterministic `DerivedData` path
3. the built app installs into a booted simulator
4. the app launches to the onboarding or PIN setup flow

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
- `scripts/install-wallet-local-apk.sh`
- `scripts/install-wallet-demo-apk.sh` as a compatibility alias for the local wallet install path
- `scripts/run-issuance-demo.sh`
- `scripts/run-verification-demo.sh`

For iOS wallet enablement, the shared workflow now also includes:

- `scripts/preflight-ios-wallet.sh`
- `scripts/build-ios-wallet-simulator.sh`
- `scripts/generate-local-mdoc-signer-chain.sh`
- `scripts/run-ios-verification-deeplink.sh`
- `scripts/smoke-ios-wallet-simulator.sh`

These should stay as wrappers around repo-level build and launch entry points.

The iOS wrappers deliberately stop at simulator build and launch. They are not a replacement for Apple Developer signing setup, provisioning, or TestFlight packaging.

## Wallet Flavor Contract

The Android wallet flavors now have explicit environment meaning in this workspace:

- `Dev` is the local wallet build and is the one that the local runbook uses
- `Demo` is the shared cloud or tester wallet build and is reserved for the public `issuer.test.instech-eudi-poc.com` and `verifier.test.instech-eudi-poc.com` flows

This split matters for document readers and verifier requests because the wallet bakes environment-specific issuer and verifier hosts into `BuildConfig`.

- local document-reader and verifier requests require the `Dev` build because they target the current LAN host and local trust material
- shared cloud document-reader and verifier requests require the `Demo` build because they target the public issuer and verifier hosts

Do not reuse a local `Dev` APK for the public cloud verifier, and do not reuse a cloud `Demo` APK for the local verifier stack.

Use these as the source-of-truth local install paths:

- repo-native install command: `cd "$CODE_ROOT/eudi-app-android-wallet-ui" && LOCAL_DEMO_HOST="$(ipconfig getifaddr en0 || ipconfig getifaddr en1)" ./gradlew buildAndInstallDevDebug --console=plain`
- wrapper install command: `cd "$CODE_ROOT/project-docs/scripts" && ./install-wallet-local-apk.sh --fresh`
- local APK output path: `$CODE_ROOT/eudi-app-android-wallet-ui/app/build/outputs/apk/dev/debug/app-dev-debug.apk`

The cloud tester APK is different: it comes from GitHub Releases in the Android wallet repository and is built from `demoRelease`.

## SD-JWT PID Credential Count Guardrail

The current Android wallet rule for `DocumentIdentifier.SdJwtPid` is intentionally `numberOfCredentials = 1` in both `Dev` and `Demo`.

Keep that value at `1` for now.

Why this is an explicit rule:

- the current SD-JWT PID issuance path returns a single credential
- the current wallet-core storage path expects the number of issuer-provided credentials to match the number of precreated pending credentials on the unsigned document
- raising the wallet rule to `10`, `60`, or any other larger pool without a matching multi-credential SD-JWT issuance contract can make issuance fail after the issuer already returned `POST /credential 200`

Treat `MdocPid` and `SdJwtPid` as different issuance shapes, not as two formats that should share the same pool size.

Only revisit this guardrail when all of the following are true:

1. the issuer really returns multiple SD-JWT credentials for the same issuance rule
2. wallet-core storage is verified to support that larger SD-JWT pending-credential pool
3. an end-to-end regression test proves the larger value works in both local and cloud-targeted wallet builds

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
privKey/PID-DS-LOCAL-UT.pem
cert/PID-DS-LOCAL-UT_cert.der
cert/PID-DS-LOCAL-UT_cert.pem
```

The issuer backend bootstrap uses that seed directory to populate the local signer files before startup. Legacy `PID-DS-0001_UT` filenames remain accepted as a fallback, but the generated local-chain workflow now uses `PID-DS-LOCAL-UT`. Without those assets, the issuance flow will fail after form submission when the backend tries to build the PID mdoc.

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
   - if you want local mdoc issuance to work cross-platform, run `./generate-local-mdoc-signer-chain.sh` before rebuilding the wallets so both wallets trust the same freshly generated local IACA root
8. Confirm Docker Desktop is running if that is your local Docker engine.
9. Check the current LAN IP with:

```bash
ipconfig getifaddr en0 || ipconfig getifaddr en1
```

The wrappers now auto-detect this Mac's LAN IP by default. You only need to uncomment `PUBLIC_HOST` and `VERIFIER_PUBLIC_HOST` in `scripts/local-demo.env` if you want to force a manual override.

For iOS work, also confirm that:

1. a full stable Xcode app is installed
1. `xcode-select -p` points at the Xcode developer directory rather than Command Line Tools
1. if needed, switch it explicitly with:

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

1. confirm the toolchain with:

```bash
xcodebuild -version
```

1. the target simulator named by `IOS_SIMULATOR_NAME` exists on this Mac

1. Confirm your Android SDK `adb` path is correct if you want the runbook to show device status.
1. Set `ANDROID_SERIAL` in `scripts/local-demo.env` if you want deterministic device targeting for install and deep-link steps.

Docker Desktop is fine for this workflow, but use the runbook commands as the source of truth for starting and checking the verifier stack. Docker Desktop is useful as a visual status view, not as a replacement for the scripted `docker compose` flow.

`PUBLIC_HOST` is the LAN IP address of this Mac, not the router IP. It can change if your DHCP lease changes, if you switch interfaces, if the network reassigns addresses, or if you move between wired and wireless connections.

If you need to stop everything explicitly, use:

```bash
cd "$CODE_ROOT/project-docs/scripts"
./stop-local-all.sh
```

Use that explicit stop when you want to tear the local stack down at the end, or when you want a manual reset before investigating logs. It is not required before the normal `./start-local-all.sh` path.

## Multiple Local Stacks

The local wrapper model can support more than one local backend stack on the same machine when you need separate worktrees for different testing goals, for example one Irish Life verifier stack and one wallet-focused stack.

The safe rule is:

- keep the Python issuer/auth/frontend ports separate if you want two full stacks
- keep the verifier Docker host ports, fixed Docker container names, and Docker Compose project name separate for the second stack
- give each worktree its own `project-docs/scripts/local-demo.env`

For a second full stack, override values such as:

```bash
AUTH_PORT=15001
ISSUER_PORT=15002
FRONTEND_PORT=15003
VERIFIER_STACK_SUFFIX=-ios
COMPOSE_PROJECT_NAME=ioswalletlocal
VERIFIER_TLS_HOST_PORT=4443
VERIFIER_BACKEND_HOST_PORT=18080
VERIFIER_UI_HOST_PORT=14300
VERIFIER_BACKEND_CONTAINER_NAME=verifier-backend-ios
VERIFIER_UI_CONTAINER_NAME=verifier-ui-ios
VERIFIER_HAPROXY_CONTAINER_NAME=verifier-haproxy-ios
VERIFIER_PUBLIC_URL=https://<host-ip>:4443
```

This keeps the primary local stack on its default ports while allowing a second full stack to run without colliding on Python service ports, Docker port bindings, fixed container names, or Compose project scoping.

The verifier wrappers now auto-derive an isolated Docker Compose project name when you use non-default verifier ports, container names, or `VERIFIER_STACK_SUFFIX` and do not set `COMPOSE_PROJECT_NAME` explicitly. Keeping `COMPOSE_PROJECT_NAME` in `local-demo.env` is still the preferred explicit setup for long-lived parallel worktrees because it makes the intended stack boundary obvious in logs and `docker ps`.

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

The Android wallet also bakes environment-specific verifier and issuer hosts into its generated `BuildConfig`. For the local `Dev` path those values are still derived from `localDemoHost`. If the Mac's LAN IP changes and you only restart the local services, verification can still fail before the consent screen because the installed APK is still pre-registered against the old verifier URL. `scripts/build-local-all.sh` and `scripts/build-local-all-clean.sh` already resync `local.properties` before rebuilding; `scripts/install-wallet-local-apk.sh` now also refuses to install a stale local APK so the mismatch is caught before device testing.

The iOS wallet does not accept the verifier backend's default local `client_id=Verifier` through its upstream OpenID4VP config unless you compile in a matching preregistered verifier entry. If the same-device verifier deeplink opens the wallet on the simulator but the verifier backend never receives a `/wallet/request.jwt/...` fetch, rebuild the simulator app with `IOS_LOCAL_VERIFIER_URL` and `IOS_LOCAL_VERIFIER_CLIENT_ID` set so the wallet trusts the local preregistered verifier before it tries to dereference `request_uri`.

For local same-device troubleshooting, keep `response_type=vp_token` present on both the outer `eudi-openid4vp://...` deep link and the signed request object served from `request_uri`. Check both the verifier backend response and any verifier UI fallback builder that reconstructs `authorization_request_uri`, because a missing outer `response_type` in either path still triggers wallet-side `MissingResponseType` before consent.

For iOS simulator troubleshooting, prefer `project-docs/scripts/run-ios-verification-deeplink.sh` before repeated Safari retries. If Safari already switches into the wallet, the custom-scheme registration is usually fine; the scripted path is more useful because it removes verifier-UI and browser handoff noise and proves whether the generated OpenID4VP deep link itself can start the proof flow.

Current iOS wallet builds also need single-credential PID issuance for local same-device verifier testing. The upstream wallet-kit batch issuance path currently saves every credential in a one-time-use PID batch under the same document id, and OpenID4VP presentation then crashes when it constructs a dictionary keyed by document id. Until that upstream path is fixed, keep iOS PID issuance at `numberOfCredentials = 1` for both mdoc and SD-JWT VC variants before using the simulator or a real iPhone for local verifier proof runs. For reusable Irish Life SD-JWT PID proof journeys, keep `SdJwtPid` on `rotateUse` with that single credential so repeat proofs do not exhaust the only usable credential.

If SMTP is not configured, the verifier backend will still expose the case flow and wallet journey, but invite and completion emails will be reported as not sent.

For local runs, the default placeholder host `smtp.example.com` is now treated as email-disabled on purpose. That prevents the Irish Life `Create case and send invite` action from blocking on a fake SMTP connection while still letting the case move to `INVITE_SENT` and expose the customer portal URL.

The Irish Life agent surface now shows which step is active during case creation versus invite sending, and it clears the spinner locally if the browser waits too long for either step. If the page reports that it stopped waiting, use `Refresh case` before retrying so you can tell whether the backend already created the case or issued the invite.

For the Irish Life SD-JWT PID flow, the local issuer frontend must advertise `eu.europa.ec.eudi.pid_vc_sd_jwt` in `CREDENTIALS_SUPPORTED`. The current local wrapper does this automatically so wallet discovery stays consistent with the verifier request.

## Existing Business Local Demo Flow

The Existing Business local journey is now customer-driven.

Use it as follows:

1. Open the customer page at `/irish-life/existing-business/customer`.
2. Enter policy number `12345678`.
3. Click `Request withdrawal`.
4. The verifier will create the case and start wallet proof automatically.
5. Use the agent page at `/irish-life/existing-business/agent` only as a read-only monitor.

The local verifier accepts only policy number `12345678` for this demo. Any other policy number is rejected immediately and no Existing Business case is created.

The customer entry page also short-circuits unsupported policy numbers locally so the demo fails immediately in the browser instead of waiting for a verifier round trip.

The verifier resolves policy `12345678` to a hard-coded internal Irish Life policy record. For the Existing Business happy path, issue a PID that matches:

1. `given_name = Patrick`
2. `family_name = Murphy`
3. `birthdate = 1980-04-12`
4. `street_address = 1 Main Street`
5. `locality = Dublin`
6. `region = Leinster`
7. `postal_code = D02 XY56`

The verifier reconstructs the expected address as:

`1 Main Street, Dublin, Leinster, D02 XY56`

The Existing Business agent surface no longer creates cases or sends invites. It monitors all in-memory Existing Business cases and should auto-expand the active withdrawal while the customer journey is in progress.

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

The issuer signer certificate under `eudi-srv-web-issuing-eudiw-py/local/cert/PID-DS-LOCAL-UT_cert.{pem,der}` is separate from the shared runtime TLS cert. `scripts/refresh-local-certs.sh` now validates that signer certificate against the active local signer private key and, when the local IACA is present, verifies that the DS certificate chains to `PIDIssuerCALocalUT.pem`. The same DS leaf must also carry `URI:$ISSUER_URL` in `subjectAltName`, because the verifier uses that SAN entry to trust SD-JWT issuer certificates during proof. If the signer material is stale, the script regenerates the full local IACA plus DS chain via `scripts/generate-local-mdoc-signer-chain.sh` instead of minting a self-signed DS leaf. The generated local CA and DS certificates are intentionally backdated by a few minutes so a freshly issued MSO cannot fail strict iOS validation because the cert `notBefore` second is later than the MSO `signed` timestamp. Legacy `PID-DS-0001_UT` paths still work as a fallback. After that signer cert changes, restart the issuer backend and reissue the credential before retrying proof.

The Irish Life verifier case flow does not rely on the manual trusted-issuer UI control. For local PID verification, `av-srv-web-verifier-endpoint-23220-4-kt/scripts/start-local-verifier.sh` now mounts the active local issuer CA PEM as the Irish Life `issuer_chain`, preferring `eudi-srv-web-issuing-eudiw-py/local/cert/PIDIssuerCALocalUT.pem` and falling back to `PIDIssuerCAUT01.pem`. The verifier parses that `issuer_chain` as PKIX trust anchors, not as directly trusted DS leaves, so `PID-DS-LOCAL-UT_cert.pem` is only a last-resort fallback for older local setups. If the local IACA or signer certificate changes, restart the verifier stack as well so new transactions carry the updated trust anchor.

The generic local proof helper `av-srv-web-verifier-endpoint-23220-4-kt/scripts/generate-verifier-deeplink.sh` must also include that same `issuer_chain` when it posts to `/ui/presentations`. Without it, the resulting transaction validates SD-JWT PID proofs with no local trust anchors and the verifier logs show `issuerChainCertificates='none'` during `PostWalletResponse`, even when the wallet presents the correct local DS certificate.

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

### iOS Simulator Build

From `project-docs/scripts` run:

```bash
./preflight-ios-wallet.sh
./build-ios-wallet-simulator.sh
```

What this confirms:

- the iOS repo is present
- full Xcode is installed and selected
- the configured simulator exists
- the wallet builds into a deterministic repo-local `DerivedData` path

The simulator app artifact used by this flow is expected at:

- `$CODE_ROOT/eudi-app-ios-wallet-ui/.build/DerivedData/Build/Products/Debug Dev-iphonesimulator/EudiWallet.app`

If you want the simulator build to target the local issuer stack instead of the hosted Dev defaults, set the iOS override values in `project-docs/scripts/local-demo.env` before running the build wrapper:

- `IOS_LOCAL_ISSUER_URL=${FRONTEND_URL}` so the wallet uses the local frontend `credential_issuer` value on `5003`
- `IOS_LOCAL_WALLET_ATTESTATION_URL=${AUTH_URL}` so wallet attestation resolves against the local auth server on `5001`
- `IOS_LOCAL_ISSUER_CLIENT_ID=wallet-dev-local` unless your local auth stack expects a different public client id
- `IOS_LOCAL_VERIFIER_URL=${VERIFIER_PUBLIC_URL}` so same-device OpenID4VP uses the active local verifier URL as preregistered verifier metadata
- `IOS_LOCAL_VERIFIER_CLIENT_ID=Verifier` so the simulator build accepts the local verifier backend's default preregistered client id
- `IOS_LOCAL_TRUSTED_HOSTS=${PUBLIC_HOST},localhost,127.0.0.1` only when the simulator must accept the local self-signed runtime certificate
- `IOS_INSTALL_LOCAL_ROOT_CERT=true` so the smoke script imports the shared runtime cert into the simulator root store before Safari or the in-app browser opens the local issuer URL

The wrapper forwards those values as Xcode build settings. If they are unset, the iOS wallet keeps the upstream hosted Dev or Demo endpoints.

The shared iOS wrappers now default `IOS_USE_LOCAL_STACK=true`, which means they automatically compile the active local issuer frontend, auth server, verifier URL, and local trusted-host list into the simulator build unless you explicitly opt out. Set `IOS_USE_LOCAL_STACK=false` only when you intentionally want a hosted-only simulator build.

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

### iOS Simulator Smoke

After the simulator build succeeds, run:

```bash
./smoke-ios-wallet-simulator.sh
```

What this confirms:

- the configured simulator can boot
- the simulator can trust the shared local runtime cert when local iOS issuer or attestation overrides are enabled
- the built app can be installed into that simulator
- the built app actually contains the expected local issuer, attestation, and verifier overrides, so the wallet can show the local credential list and same-device verifier path
- the app can be launched by bundle identifier

This is still a launch smoke, not a full issuance or verifier proof. The iOS app now has explicit local issuer, attestation, and host-scoped TLS override seams, but end-to-end issuance and same-device verifier validation remain separate follow-up checks.

### 3. Fresh APK Installation

```bash
./install-wallet-local-apk.sh
```

If the phone already has a higher-version wallet package installed, use:

```bash
./install-wallet-local-apk.sh --fresh
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

If you need live Android wallet evidence during a failing presentation attempt, tail the wallet request-matching logs in a second terminal:

```bash
./watch-android-wallet-presentation-logs.sh --clear
```

This follows the same `ADB_BIN` and `ANDROID_SERIAL` resolution as the other shared wrappers and focuses on the OpenID4VP request-receipt and `NoData` matching path.

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

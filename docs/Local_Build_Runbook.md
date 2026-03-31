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
./build-local-all.sh
./start-local-all.sh
./smoke-local-all.sh
./install-wallet-demo-apk.sh --fresh
```

`./smoke-local-all.sh` is intentionally before `./install-wallet-demo-apk.sh --fresh`. The smoke step validates the local services and verifier stack first, then the APK install step prepares the phone for issuance and verification.

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
2. Confirm the shared local certificate and key paths are correct.
3. Confirm Docker Desktop is running if that is your local Docker engine.
4. Check the current LAN IP with:

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

2. Pane 2: wrapped Python service logs

```bash
cd "$CODE_ROOT/project-docs/.local/logs"
tail -F auth-server.log issuer-backend.log issuer-frontend.log
```

3. Pane 3: verifier Docker status

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

4. Pane 4: device targeting and install

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

## Next Evolution

When the build system grows up, keep this split:

1. repository-local build logic stays inside each implementation repo
2. cross-repo orchestration stays outside the implementation repos
3. local and cloud should share the same service naming, URLs, and health-check model where possible

That is the reason these wrapper scripts live in `project-docs` rather than inside one of the six implementation repositories.

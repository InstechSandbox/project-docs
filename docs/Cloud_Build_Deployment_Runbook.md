# Cloud Build And Deployment Runbook

## Purpose

This document records the agreed first-phase cloud build and deployment design for the InstechSandbox EUDI proof of concept.

It is the canonical reference for how local build, GitHub Actions, AWS deployment, artifact publication, and the `cloud-build` workstream should fit together.

## Scope

The first phase covers:

- repeatable GitHub Actions based build and deployment for the issuer and verifier stacks
- repeatable Android artifact publication
- first-phase iOS build and deployment planning with TestFlight as the target distribution path
- a single shared AWS environment named `test`
- minimal-cost infrastructure choices that still preserve a sound design

The near-term delivery target inside that phase is narrower and should guide cost decisions: a public-internet end-to-end demo where a mobile wallet can request a credential and then complete a proof or verification flow against the cloud-hosted services.

This phase does not replace the local build. The local build remains the effective development baseline and the fastest integration path.

## Agreed Operating Model

### Environment Model

- local remains the effective `dev` environment for day-to-day engineering and troubleshooting
- the first cloud-hosted environment is `test`
- there is no separate cloud `dev` environment in phase 1

### Trigger Model

- local commit and push hooks remain the first-line quality gates before code is pushed
- GitHub Actions should trigger on `push` to `main`
- for phase 1, pull request workflows are not required because the build is still maturing
- `workflow_dispatch` should be available for manual rebuild, redeploy, or smoke-only runs

### Build And Deploy Separation

- each application repository should own its own validation and packaging workflow
- build workflows must produce immutable artifacts such as container images, APKs, or iOS build outputs
- deployment workflows must consume those artifacts rather than rebuilding ad hoc inside the deployment step

### AWS Runtime Model

- AWS ECS Fargate is the default runtime target for containerized services in phase 1
- Route 53, ACM, and an application load balancer should provide public DNS and TLS termination
- ECR should store container images
- AWS Systems Manager Parameter Store or Secrets Manager should hold environment-specific configuration and secrets
- GitHub OIDC to AWS must be used instead of long-lived AWS keys in GitHub secrets
- local self-signed certificates are a local-only development convenience and should not be copied into the cloud runtime model; cloud-facing endpoints should use ACM-managed certificates unless a separately documented private trust requirement exists

### Repository Responsibility Model

- application repositories own source, repo-native tests, Dockerfiles, and packaging logic
- application repositories also own artifact publication callers, such as Docker image publication to ECR or mobile bundle publication, because publication is part of packaging rather than deployment
- the `.github` repository should own reusable GitHub Actions workflows
- cross-repo design, runbooks, and architecture notes belong in `project-docs`
- infrastructure as code should live in a dedicated deployment repository named `instechsandbox-eudi-deploy`

### Repo Boundary For Packaging vs Deployment

- application repositories should build and publish immutable artifacts on `push` to `main`
- the dedicated deployment repository should consume published artifact references or digests and deploy them into the `test` environment
- deployment workflows must not rebuild application artifacts inside the deployment repository
- reusable workflow primitives should stay in `.github`, but environment-specific AWS logic should not
- AWS environment logic should stay centralized in `instechsandbox-eudi-deploy` rather than being spread across application repositories or `.github`
- repeated artifact publication mechanics should be abstracted into reusable workflows in `.github` rather than copy-pasted caller logic in each application repository

In practical terms, the next ECR publication step belongs in each service repository package workflow, while the AWS role, ECR repository definitions, ECS services, load balancer wiring, Route 53, ACM, and per-environment deployment orchestration belong in `instechsandbox-eudi-deploy`.

That means the dedicated deployment repository is the home for the phase-1 infrastructure as code.

## Workstream Rule

- use the workstream name `cloud-build` across repos, workspace files, documentation, and acceptance criteria
- use `wip/cloud-build` branches for the isolated workstream checkouts
- keep the cloud-build workstream additive and reviewable; avoid mixing unrelated runtime changes into it

## Phase 1 Delivery Shape

### Issuer Stack

The issuer stack consists of:

- `eudi-srv-issuer-oidc-py`
- `eudi-srv-web-issuing-eudiw-py`
- `eudi-srv-web-issuing-frontend-eudiw-py`

The agreed direction is to move the issuer stack toward Docker-first packaging while preserving local runs.

This means:

- local developer flows may still use the current run scripts and wrappers
- local Python venv bootstrap should prefer Python 3.11 to stay close to the current Docker packaging baseline, with 3.10 or 3.9 only as explicit local fallback choices
- packaging contracts should converge on container images and generated runtime config
- local and cloud should use the same packaging model wherever practical to avoid maintaining two diverging systems

### Verifier Stack

The verifier stack consists of:

- `av-srv-web-verifier-endpoint-23220-4-kt`
- `eudi-web-verifier`

The verifier backend and verifier UI should publish deployable artifacts independently, while deployment into the `test` environment should preserve a coherent issuer-verifier integration order.

### Mobile Distribution

- Android artifacts should be published through public GitHub Releases in phase 1
- iOS should target TestFlight in phase 1
- mobile artifact publication should be treated as part of the ecosystem release flow, but it should remain separate from the service deployment mechanics

For the wallet apps, environment targeting and distribution channel are related but distinct:

- Android `Dev` is the local engineering flavor and should stay bound to local issuer and local verifier readers
- Android `Demo` is the shared cloud tester flavor and should stay bound to the public `test.instech-eudi-poc.com` issuer and verifier readers
- iOS `Dev` is the local Xcode path and now defaults to local issuer hosts through the tracked xcconfig and `Wallet.plist` path, while iOS `Demo` is the shared cloud or TestFlight path and now defaults to the public `test.instech-eudi-poc.com` issuer hosts
- launcher or display names should make the distinction visible to operators so both installs can coexist without ambiguity

The reader or verifier environment matters as much as the app binary origin. A local-reader wallet build should not be reused against the public verifier slice, and a cloud-reader wallet build should not be reused against the local verifier slice, because preregistered verifier assumptions and redirect handling are environment-specific.

For iOS specifically, the issuer hosts are now variant-driven through `Wallet/Config/*.xcconfig` into `Wallet.plist`, and the `Dev` variant can be redirected to a device-reachable LAN host via an untracked `Wallet/Config/WalletLocalOverrides.xcconfig` file. Remote verifier flows still depend on using the matching local or public verifier URL in Safari or QR entry.
The Android `publish-test-apk` workflow currently expects these repository secrets before it can generate a downloadable signed `Demo` APK:

- `ANDROID_KEY_ALIAS`: alias of the release signing key inside that keystore
- `ANDROID_KEY_PASSWORD`: password used for both the key and store in the current Gradle signing config; because the workflow generates a JKS keystore on the runner, this must be at least 6 characters

The current workflow generates a JKS keystore on the runner from `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD` rather than restoring a binary keystore blob from secrets. That keeps the publication path reliable in GitHub Actions, but it also means the signing identity is workflow-generated unless a persistent keystore transport is added later.

For local `demoRelease` packaging in the cloud-build workspace, the Android repo now supports an untracked `local.signing.properties` file alongside the ignored repo-root `sign` keystore. The local contract is:

- `sign`: local JKS keystore file in the Android repo root
- `local.signing.properties`: untracked file containing `androidKeyAlias` and `androidKeyPassword`
- `./preflight-demo-release-signing.sh`: local guardrail that verifies the alias and password resolve and actually match `sign` before Gradle reaches `packageDemoRelease`

Recommended local sequence:

```bash
cd "$CODE_ROOT/eudi-app-android-wallet-ui"
cp local.signing.properties.example local.signing.properties
./preflight-demo-release-signing.sh
LOCAL_DEMO_HOST=test.instech-eudi-poc.com ./gradlew :app:assembleDemoRelease --console=plain
```

If the preflight fails with an alias or password mismatch, do not continue into Gradle packaging. Update `local.signing.properties` to match the local keystore or replace the ignored `sign` file with the intended local release keystore first.

The workflow now builds with `-x workspaceClean` because the current Android repo clean graph can race with generated outputs during assemble tasks even though the wallet flavor wiring itself is valid.

The workflow is also self-contained for release-sidecar generation. Instead of checking out the private `project-docs` repo during GitHub Actions, it now creates a minimal Android compliance bundle directly from the wallet repo by packaging:

- `LICENSE.txt`
- `NOTICE.txt`
- `gradle/libs.versions.toml`
- source repository and commit metadata
- a generated proof-of-concept release record markdown file

### Android Test APK Publication Steps

The minimum publication sequence is:

1. ensure the Android repo changes that add or update `.github/workflows/publish-test-apk.yml` are committed and pushed
2. populate the required repository secrets in `InstechSandbox/eudi-app-android-wallet-ui`
3. dispatch the workflow with a release tag and release name
4. verify the workflow run and resulting GitHub release assets

Example command sequence from a machine that has GitHub CLI access:

```bash
REPO=InstechSandbox/eudi-app-android-wallet-ui
KEYSTORE_PATH=/absolute/path/to/android-release.keystore
RELEASE_TAG=cloud-build-20260412-demo-apk-v1
RELEASE_NAME="Cloud Build Demo APK v1"

gh auth status -h github.com

gh secret set ANDROID_KEY_ALIAS \
   -R "$REPO" \
   --body 'your-key-alias'

gh secret set ANDROID_KEY_PASSWORD \
   -R "$REPO" \
   --body 'your-keystore-password-with-at-least-6-characters'

gh workflow run publish-test-apk.yml \
   -R "$REPO" \
   -f release_tag="$RELEASE_TAG" \
   -f release_name="$RELEASE_NAME" \
   -f prerelease=false

gh run list -R "$REPO" --workflow publish-test-apk.yml --limit 5
gh release view "$RELEASE_TAG" -R "$REPO"
```

Expected secret value formats:

- `ANDROID_KEY_ALIAS`: plain text alias string for the runner-generated signing key
- `ANDROID_KEY_PASSWORD`: plain text password string used for both the key and store in the Android Gradle signing config; it must be at least 6 characters to satisfy `keytool` for JKS generation

Expected workflow-dispatch inputs:

- `release_tag`: immutable release identifier and Git tag, for example `cloud-build-20260412-demo-apk-v1`
- `release_name`: human-readable title shown on the GitHub release page
- `prerelease`: default `false` so the latest APK release is visible on the repository homepage; set it to `true` only when you intentionally want a prerelease drop
The resulting GitHub release should contain at least:

- one signed `demoRelease` APK from `app/build/outputs/apk/demo/release/`
- one compliance sidecar zip generated under `.local/mobile-compliance/<release-tag>-android-compliance.zip`

## Recommended Workflow Shape

### Repository-Level Workflows

Each application repository should eventually expose:

1. validation workflow
   - trigger: `push` to `main`, optional `workflow_dispatch`
   - runs repo-native deterministic checks

2. package workflow
   - trigger: successful validation
   - builds immutable artifact
   - publishes artifact to the correct registry or release target

3. optional repo-local smoke workflow
   - verifies the packaged artifact or built image starts correctly

### Reusable Workflow Foundation In `.github`

The first reusable workflow layer now exists in the InstechSandbox `.github` repository.

Current reusable workflows:

- `reusable-python-validation.yml`
- `reusable-node-validation.yml`
- `reusable-gradle-validation.yml`
- `reusable-docker-build.yml`
- `reusable-ecr-publish.yml`
- `reusable-deployment-scaffold.yml`

These workflows are intentionally generic. Application repositories are expected to add thin caller workflows that provide their own working directory, install commands, validation commands, Docker context, and tags.

This layer now covers reusable validation, reusable Docker packaging, reusable ECR publication, and a deployment scaffold contract.

The deployment scaffold is deliberately non-executing. It creates a deployment manifest artifact and summary that describe what a future deployment repository should consume, but it does not apply infrastructure changes or deploy workloads into AWS.

The first caller workflows now exist in the issuer and verifier application repositories for validation on `push` to `main` and `workflow_dispatch`.

Current caller coverage:

- `eudi-srv-issuer-oidc-py`
- `eudi-srv-web-issuing-eudiw-py`
- `eudi-srv-web-issuing-frontend-eudiw-py`
- `av-srv-web-verifier-endpoint-23220-4-kt`
- `eudi-web-verifier`

Those caller workflows now cover validation, manual packaging, automatic publish after successful validation, and automatic runtime deploy for the shared AWS test environment.

The next caller layer now exists for Docker-based package workflows in the same issuer and verifier repositories.

Current package caller coverage:

- `eudi-srv-issuer-oidc-py`
- `eudi-srv-web-issuing-eudiw-py`
- `eudi-srv-web-issuing-frontend-eudiw-py`
- `av-srv-web-verifier-endpoint-23220-4-kt`
- `eudi-web-verifier`

Current package workflow behavior:

- supports manual `workflow_dispatch`
- builds the repository Docker image through the reusable Docker build workflow
- records image tags and build metadata without pushing to a registry

Package is now manual-only so a normal `main` push does not spend runner time on a second non-publishing image build after validation.

The first thin publish caller workflows now also exist in the issuer and verifier service repositories.

Current publish caller coverage:

- `eudi-srv-issuer-oidc-py`
- `eudi-srv-web-issuing-eudiw-py`
- `eudi-srv-web-issuing-frontend-eudiw-py`
- `av-srv-web-verifier-endpoint-23220-4-kt`
- `eudi-web-verifier`

Current publish workflow behavior:

- triggers automatically after successful `Validation` runs on `main`
- supports manual `workflow_dispatch`
- defaults to the current test AWS region and publish-role ARN while still allowing manual override through workflow inputs
- uses the reusable ECR publication workflow in `.github` for AWS login, ECR authentication, build-and-push, and summary output
- keeps caller logic thin by passing only repo-specific image names, Dockerfile paths, and target repository names
- calls the deploy repository runtime workflow after a successful publish so the shared `test` stack converges automatically

The caller changes are now split this way:

- `.github`: provide reusable publication primitives for AWS login, tagging, registry publication, and shared summary/reporting behaviour
- application repos: keep thin caller workflows that supply repo-specific image names, tags, publication inputs, and the single changed component digest without re-implementing shared publish mechanics
- `instechsandbox-eudi-deploy`: define the ECR repositories, IAM trust, ECS task and service definitions, environment configuration, deployment orchestration, and manifest digest resolution

### Environment-Level Deployment Workflow

The dedicated deployment repository should expose:

1. infrastructure plan/apply workflow
2. service deployment workflow that consumes artifact versions or image digests
3. post-deploy smoke workflow for the `test` environment
4. rollback or redeploy workflow

The reusable deployment scaffold in `.github` remains the reviewable handoff contract. It captures:

- target environment
- deployable component name
- artifact kind and immutable artifact reference
- expected deploy repository
- optional smoke URL or smoke path metadata

That scaffold keeps the source repositories additive and reviewable while the deploy repository owns the actual AWS rollout.

The current phase-1 handoff contract is:

- service publish workflows push container images to ECR through the shared reusable workflow in `.github`
- each publish workflow then emits a deployment scaffold artifact that records the immutable image digest for the `test` environment
- `instechsandbox-eudi-deploy` consumes the just-published component digest plus the current `main` tag of the other four components, resolves every artifact reference to an immutable ECR digest, and applies the runtime scaffold automatically
- digest resolution happens inside the deploy workflow before Terraform renders tfvars, so ECS rollouts do not rely on mutable `:main` tags alone
- the deploy repository keeps the manual foundation bootstrap path, while runtime deploy is now the standard post-publish path for the five cloud services

The current automatic runtime-deploy defaults are:

- publish role: `arn:aws:iam::718959508203:role/GitHubActionsInstechSandboxPublish`
- deploy role: `arn:aws:iam::718959508203:role/GitHubActionsInstechSandboxDeploy`
- runtime and foundation state bucket: `instechsandbox-eudi-terraform-state-718959508203-eu-west-1`
- runtime lock table: `instechsandbox-eudi-terraform-locks`
- public base domain: `test.instech-eudi-poc.com`
- public hosted zone id: `Z01745022CR6TI0M2DI9E`
- runtime profile: `full-public-demo`
- the same foundation workflow can switch to an S3 backend through explicit workflow inputs once the backend bucket and optional lock table exist

For the current public issuer slice, the generated runtime config must also preserve two cloud-specific contracts:

- the auth server task must render its runtime config with an explicit writable `AUTH_LOG_FILE` path so Python file logging does not fail container startup
- the issuer backend task must point `TRUSTED_CAS_PATH`, `PRIVKEY_PATH`, `NONCE_KEY`, and `CREDENTIAL_KEY` at the demo assets that are intentionally packaged into the current proof-of-concept image, rather than relying on the local-only `/etc/eudiw/pid-issuer/...` defaults
- the packaged Utopia SD-JWT signer certificate inside those demo assets is local by default, so cloud issuer startup must rewrite the DS certificate SAN to the configured public `SERVICE_URL` before issuing JWT PID credentials; otherwise verifier SD-JWT validation rejects the posted proof because the embedded `x5c` leaf still advertises the local `192.168.x.x` issuer URI
- the issuer backend `VERIFY_USER_ENDPOINT` must target the auth-server host, currently `https://auth.test.instech-eudi-poc.com/verify/user`, not the issuer-backend host, because the browser handoff after the dynamic authorization screen calls the auth server verification route directly
- the issuer backend task must also override revocation settings in cloud with `REVOCATION_SERVICE_URL=https://issuer-api.<base-domain>/token_status_list/take` and `REVOKE_SERVICE_URL=https://issuer-api.<base-domain>/token_status_list/set`; otherwise the container loads the repo `.env` defaults, tries the local private-IP revocation endpoint, and can stall credential issuance long enough for the internal `/dynamic/dynamic_R2` request to time out
- when manually rebuilding the issuer backend image, build from the backend repository working tree, not the similarly named frontend repository, and validate the pushed digest against the running ECS task before retesting the browser journey
- keep a backend-only smoke check in the rollout path, for example `https://issuer-api.<base-domain>/credential_offer_choice?...` or another route that cannot be served by the frontend image, so a host-routing or misbuilt-image regression is detected before user retesting starts
- the workspace now includes `instechsandbox-eudi-deploy/deploy/scripts/smoke_test_public_issuer.sh` for that check; use it after issuer deployments to confirm the running backend task, public frontend redirect, and backend-only `credential_offer_choice` endpoint all line up before retrying issuance or proof flows

The current public `test` environment endpoints are:

- `https://auth.test.instech-eudi-poc.com/.well-known/openid-configuration`
- `https://issuer-api.test.instech-eudi-poc.com/`
- `https://issuer.test.instech-eudi-poc.com/`
- `https://verifier-api.test.instech-eudi-poc.com/actuator/health`
- `https://verifier.test.instech-eudi-poc.com/`

For the current public verifier slice, keep the UI-to-backend routing contract explicit:

- the Angular verifier UI currently issues relative API calls under `/ui`, `/wallet`, and `/utilities`
- the cloud `eudi-web-verifier` Nginx container must proxy those paths to `HOST_API` instead of serving them as static routes
- without that proxy, browser POSTs such as `/ui/irish-life/new-business/cases` terminate at the UI container and return `405`, even when the verifier backend itself is healthy
- the verifier backend task must also carry explicit Irish Life PID trust material. The current emergency cloud contract is `VERIFIER_IRISHLIFE_PIDISSUERCHAIN_PATH=classpath:irishlife/LocalUtopiaDsSelfSigned.pem`, because the live issuer task is emitting a self-signed SD-JWT leaf for the public issuer URL rather than a CA-signed leaf chained to `PIDIssuerCAUT01.pem`
- keep that PEM packaged with the verifier image and reviewed in `instechsandbox-eudi-deploy` runtime config; if the env var is missing or points at a non-existent resource, both Irish Life flows still render but proof submission fails with `IssuerCertificateIsNotTrusted`
- this is a compatibility bridge, not the target architecture. The durable fix is to provision cloud signer assets that let the issuer emit a CA-signed public-SAN leaf, then move verifier trust back to the reviewed issuer CA chain instead of pinning a self-signed DS certificate

For a blank AWS account, the correct point to start cloud testing is now the durable account bootstrap layer:

- create the Terraform state bucket and optional lock table first
- create GitHub OIDC trust and the minimal deploy and publish roles next
- apply the Terraform test foundation after that
- only then move on to publishing a real service image and later runtime wiring

The intended operating rule is:

- bootstrap the AWS account once from a local admin-authenticated shell
- use GitHub Actions as the standard operating path after that
- keep local development cloud-light unless cloud-specific behavior is the thing being validated

In the current workspace, the deploy repository publishes from `InstechSandbox`, while the service repositories may be worked on as `InstechSandbox` origins with `eu-digital-identity-wallet` upstream remotes, so the AWS bootstrap trust configuration must allow the publish role to trust both owners where needed.

`instechsandbox-eudi-deploy` now exists and contains the initial Terraform-based phase-1 AWS baseline. That repository is the home for the actual infrastructure as code for:

- ECR repositories and lifecycle policies
- IAM roles and GitHub OIDC trust policies
- ECS clusters, task definitions, services, and service-to-service wiring
- load balancer listeners, target groups, Route 53 records, and ACM certificates
- Systems Manager Parameter Store or Secrets Manager bindings
- per-environment deployment manifests and smoke orchestration

The deploy repository currently includes:

- a Terraform root for the shared `test` environment
- a first shared foundation module covering ECR, ECS cluster, and log-group scaffolding
- a separate Terraform root for `test-runtime` that consumes the foundation remote state, creates low-cost ECS runtime scaffolding, and provisions the ECS service-linked role automatically when a blank AWS account does not have it yet
- repository-local workflow scaffolding for Terraform validation, deployment-plan rendering, and runtime scaffold apply

## Deployment Order

The first-phase deployment order should be explicit and automated:

1. shared AWS infrastructure
2. issuer authorization server
3. issuer backend
4. issuer frontend
5. verifier backend
6. verifier UI
7. cloud smoke checks
8. Android and iOS distribution publication as required by the release flow

Manual documentation of the order is useful, but the deployment system should enforce the order rather than relying on operator memory.

## Idempotence Rule

All build and deployment steps should be written so repeated execution converges on the same result.

This means:

- infrastructure should be defined as code
- deployment should consume versioned artifacts
- runtime configuration should be generated deterministically from templates and environment-specific inputs
- tracked source files must not be rewritten in place for local or cloud environment setup

## Technical Debt That Must Be Resolved First

Before the full cloud deployment design is implemented, the current local runtime drift should be corrected.

### Tracked Runtime JSON Must Stop Being Mutated

These tracked files currently contain local host or local IP drift and should be moved to generated runtime outputs or template-plus-override patterns:

- `eudi-srv-issuer-oidc-py/config.json`
- `eudi-srv-issuer-oidc-py/openid-configuration.json`
- `eudi-srv-web-issuing-eudiw-py/app/metadata_config/metadata_config.json`
- `eudi-srv-web-issuing-eudiw-py/app/metadata_config/openid-configuration.json`
- `eudi-srv-web-issuing-eudiw-py/app/metadata_config/oauth-authorization-server.json`

### Tracked SAN Config Files Must Become Generated Templates

These tracked files should stop containing machine-specific IP addresses and should instead be generated from templates at runtime:

- `eudi-srv-issuer-oidc-py/san.cnf`
- `eudi-srv-web-issuing-eudiw-py/ip-san.conf`
- `eudi-srv-web-issuing-frontend-eudiw-py/san.cnf`

## Cost Guidance

The `test` environment should minimize AWS cost while preserving clean design boundaries.

Phase 1 design choices should therefore prefer:

- a single shared `test` environment
- ECS Fargate over more operationally heavy runtime choices
- only the components needed for end-to-end issuer and verifier interaction
- explicit shutdown, scale, or minimal-capacity defaults where they do not undermine repeatability
- the smallest viable public-internet footprint that can demonstrate mobile issuance plus proof/verification before introducing cleaner but more expensive always-on infrastructure

The current runtime scaffold follows that rule by creating ECS task definitions and ECS services from immutable image references, but keeping every service at `desired_count = 0` until the runtime configuration and secret contract is explicitly wired for cloud execution.

For the issuer authorization server specifically, the container runtime contract should stay as plain HTTP on internal port `5001`, with cloud TLS terminated at ingress. Local self-signed HTTPS remains a separate helper path and should not drive the ECS task definition.

The first public-internet ingress step should also stay minimal and explicit:

- use one shared public ALB for the `test` runtime instead of separate public entry points per service
- terminate TLS on that ALB with ACM-managed certificates
- use host-based routing for the five phase-1 service hosts such as `auth.<base-domain>`, `issuer.<base-domain>`, `issuer-api.<base-domain>`, `verifier.<base-domain>`, and `verifier-api.<base-domain>`
- make those Route 53 hostnames the durable public contract for wallets and operators rather than exposing ECS task public IPs directly
- do not use Elastic-IP-per-service or direct task-address publication as the default durability mechanism unless a separately documented exception is approved
- keep that ingress path optional until a delegated Route 53 zone and reviewed public hostnames are available
- make the fixed-cost implication of the ALB explicit, because this is the first meaningful always-on cost in the runtime path

That runtime configuration contract should stay explicit and reviewable:

- plain non-secret settings should be represented as reviewed environment-variable config
- secret values should enter ECS through Parameter Store or Secrets Manager references rather than tracked files or image rebuilds
- cloud-facing TLS should terminate with ACM-managed certificates on ingress rather than by carrying the local self-signed certificate model into AWS
- when required cloud values are not available yet, keep `environment` and `secrets` empty for that service rather than inventing placeholders, and capture the missing inputs as explicit required keys and blockers in the reviewed runtime-config manifest
- use the runtime-config manifest as the evidence-backed handoff between repo-level config discovery and the later ingress, DNS, and secret-provisioning steps
- allow the reviewed runtime-config manifest to carry intentional `desired_count` values so the deployment system can activate one public slice at a time instead of turning on every service together
- where the hostname pattern is already agreed, prefer generating the first runtime-config slice from the base domain and profile rather than hand-editing repeated public URLs across five services
- for the `verifier-first` public slice, explicitly disable Spring mail health checks in the generated verifier-backend environment until real SMTP credentials exist, because placeholder mail settings must not make the shared `/actuator/health` endpoint fail the ALB target check

Do not distort the architecture solely for short-term savings, but prefer the smallest viable infrastructure footprint that keeps the design maintainable.

## Documentation Rule For This Stream

If the implementation changes any of the following, update this runbook and the AI working agreement in the same work cycle:

- trigger model
- environment model
- packaging model
- deployment order
- artifact publication strategy
- AWS runtime or trust model assumptions

## Next Recommended Implementation Sequence

1. clean up tracked local-IP drift and convert runtime files to generated inputs
2. converge the issuer trio on Docker-first packaging while preserving local runs
3. add thin caller workflows in each application repository that consume the reusable workflows in `.github`
4. add package caller workflows that build immutable container artifacts without registry publication drift
5. apply the Terraform-based `test` environment baseline from `instechsandbox-eudi-deploy`
6. wire reusable ECR publication and deployment into `test`
7. apply the separate `test-runtime` scaffold with immutable image refs and zero desired count as the low-cost runtime bridge
8. add runtime configuration, secret injection, and then scale selected services above zero
9. add cloud smoke tests
10. add Android GitHub Releases publication and iOS TestFlight publication

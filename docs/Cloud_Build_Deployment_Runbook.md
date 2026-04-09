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

### Repository Responsibility Model

- application repositories own source, repo-native tests, Dockerfiles, and packaging logic
- the `.github` repository should own reusable GitHub Actions workflows
- cross-repo design, runbooks, and architecture notes belong in `project-docs`
- infrastructure as code should live in a dedicated deployment repository named `instechsandbox-eudi-deploy`

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
- `reusable-deployment-scaffold.yml`

These workflows are intentionally generic. Application repositories are expected to add thin caller workflows that provide their own working directory, install commands, validation commands, Docker context, and tags.

This layer now covers reusable validation, reusable Docker packaging, and a deployment scaffold contract.

The deployment scaffold is deliberately non-executing. It creates a deployment manifest artifact and summary that describe what a future deployment repository should consume, but it does not apply infrastructure changes or deploy workloads into AWS.

The first caller workflows now exist in the issuer and verifier application repositories for validation on `push` to `main` and `workflow_dispatch`.

Current caller coverage:

- `eudi-srv-issuer-oidc-py`
- `eudi-srv-web-issuing-eudiw-py`
- `eudi-srv-web-issuing-frontend-eudiw-py`
- `av-srv-web-verifier-endpoint-23220-4-kt`
- `eudi-web-verifier`

Those caller workflows currently cover validation only. Packaging, registry publication, and deployment callers remain the next phase.

The next caller layer now exists for Docker-based package workflows in the same issuer and verifier repositories.

Current package caller coverage:

- `eudi-srv-issuer-oidc-py`
- `eudi-srv-web-issuing-eudiw-py`
- `eudi-srv-web-issuing-frontend-eudiw-py`
- `av-srv-web-verifier-endpoint-23220-4-kt`
- `eudi-web-verifier`

Current package workflow behavior:

- triggers after successful `Validation` runs on `main`
- supports manual `workflow_dispatch`
- builds the repository Docker image through the reusable Docker build workflow
- records image tags and build metadata without pushing to a registry yet

Registry publication is still intentionally deferred until GitHub OIDC to AWS and the dedicated deployment repository are wired.

### Environment-Level Deployment Workflow

The dedicated deployment repository should eventually expose:

1. infrastructure plan/apply workflow
2. service deployment workflow that consumes artifact versions or image digests
3. post-deploy smoke workflow for the `test` environment
4. rollback or redeploy workflow

Until that repository exists, the reusable deployment scaffold in `.github` is the handoff contract. It captures:

- target environment
- deployable component name
- artifact kind and immutable artifact reference
- expected deploy repository
- optional smoke URL or smoke path metadata

That scaffold keeps the source repositories additive and reviewable without pretending deployment automation is already complete.

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
5. create the `instechsandbox-eudi-deploy` repository for infrastructure as code and environment deployment
6. wire registry publication and deployment into `test`
7. add cloud smoke tests
8. add Android GitHub Releases publication and iOS TestFlight publication

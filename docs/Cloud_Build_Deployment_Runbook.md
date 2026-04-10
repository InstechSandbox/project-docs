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

The first thin publish caller workflows now also exist in the issuer and verifier service repositories.

Current publish caller coverage:

- `eudi-srv-issuer-oidc-py`
- `eudi-srv-web-issuing-eudiw-py`
- `eudi-srv-web-issuing-frontend-eudiw-py`
- `av-srv-web-verifier-endpoint-23220-4-kt`
- `eudi-web-verifier`

Current publish workflow behavior:

- triggers by manual `workflow_dispatch`
- requires the operator to provide the AWS region and OIDC role ARN as manual workflow inputs until environment-level publication settings are standardized
- uses the reusable ECR publication workflow in `.github` for AWS login, ECR authentication, build-and-push, and summary output
- keeps caller logic thin by passing only repo-specific image names, Dockerfile paths, and target repository names

When that next step is added, the caller changes should be split this way:

- `.github`: provide reusable publication primitives for AWS login, tagging, registry publication, and shared summary/reporting behaviour
- application repos: keep thin caller workflows that supply repo-specific image names, tags, and publication inputs without re-implementing shared publish mechanics
- `instechsandbox-eudi-deploy`: define the ECR repositories, IAM trust, ECS task and service definitions, environment configuration, and deployment orchestration

### Environment-Level Deployment Workflow

The dedicated deployment repository should eventually expose:

1. infrastructure plan/apply workflow
2. service deployment workflow that consumes artifact versions or image digests
3. post-deploy smoke workflow for the `test` environment
4. rollback or redeploy workflow

Until full deployment automation is in place, the reusable deployment scaffold in `.github` is the handoff contract. It captures:

- target environment
- deployable component name
- artifact kind and immutable artifact reference
- expected deploy repository
- optional smoke URL or smoke path metadata

That scaffold keeps the source repositories additive and reviewable without pretending deployment automation is already complete.

The current phase-1 handoff contract is:

- service publish workflows push container images to ECR through the shared reusable workflow in `.github`
- each publish workflow then emits a deployment scaffold artifact that records the immutable image digest for the `test` environment
- `instechsandbox-eudi-deploy` remains the repository that consumes those immutable artifact references for deployment planning and rollout
- the deploy repository can render a test deployment manifest directly from immutable image references passed into its planning workflow, so candidate rollouts do not require hand-editing the checked-in manifest first
- the deploy repository now has a manual bootstrap foundation-apply workflow for the current Terraform root, and that workflow explicitly uses runner-local state artifacts until a remote backend is introduced
- the same foundation workflow can switch to an S3 backend through explicit workflow inputs once the backend bucket and optional lock table exist

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
- a separate Terraform root for `test-runtime` that consumes the foundation remote state and creates low-cost ECS runtime scaffolding
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

The current runtime scaffold follows that rule by creating ECS task definitions and ECS services from immutable image references, but keeping every service at `desired_count = 0` until the runtime configuration and secret contract is explicitly wired for cloud execution.

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

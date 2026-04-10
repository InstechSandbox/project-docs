# AI Working Agreement

## Purpose

This document defines the shared working agreement for AI-assisted development across the InstechSandbox EUDI proof of concept.

## Project Brief

- The project currently maintains a working local baseline across six forked EUDI reference repositories plus two new repositories.
- The next major delivery objective is an Irish Life branded verifier proof of concept that mimics selected real member journeys.
- Subsequent streams include AWS deployment automation, stronger smoke and acceptance testing, iPhone enablement, and continuous `project-docs` updates.
- The active cloud deployment workstream is `cloud-build`, which targets one shared AWS environment named `test` while preserving the local build as the effective development baseline.

## Deliverables

1. Build a branded Irish Life verifier proof of concept for two target journeys.
2. Build GitHub Actions driven deployment into AWS `test` for issuer, verifier, Android distribution, and iOS distribution preparation.
3. Improve smoke coverage and add acceptance test coverage.
4. Enable the iPhone reference implementation.
5. Keep `project-docs` updated iteratively as architecture, standards interpretation, and implementation evolve.

## Mandatory Guidance

- Use GPT-5.4 as the default reasoning model for standards-sensitive and multi-repo tasks.
- Treat the EIDAS ARF and the local standards brief as mandatory constraints.
- Before any protocol-facing change, identify which standards and project documents apply.
- Prefer minimal, traceable changes over broad refactors unless explicitly requested.
- If behaviour, architecture, environment setup, CI/CD, or test strategy changes, update `project-docs` in the same task.
- Do not mix unrelated tasks in one commit.
- When a change spans multiple repos, preserve the same workstream name, issue reference, and acceptance criteria across repos.
- Use deterministic tests and linters as mandatory gates. AI review is advisory and must not be the only quality gate.

## Repo Map

- `.github`: organization-level shared engineering guidance and future shared workflows.
- `project-docs`: canonical cross-repo architecture, standards, runbook, and working-agreement documentation.
- `eudi-app-android-wallet-ui`: reference wallet implementation and local mobile integration anchor.
- `eudi-srv-issuer-oidc-py`: authorization server for issuance flows.
- `eudi-srv-web-issuing-eudiw-py`: issuer backend.
- `eudi-srv-web-issuing-frontend-eudiw-py`: issuer web frontend and supporting assets.
- `av-srv-web-verifier-endpoint-23220-4-kt`: verifier protocol and relying-party backend.
- `eudi-web-verifier`: verifier web UI.

## Branch And Workstream Conventions

- `main` is the canonical long-lived integration branch.
- For each repository in a multi-repo workstream, keep one canonical local checkout on `main` outside the workstream directory and create the workstream copy as a linked `git worktree`, not as a separate clone.
- In `/Users/bg/Dropbox/svn/code/workstreams/<stream>/...`, the expected git layout is a `.git` file that points back to the canonical checkout; a `.git` directory usually means the repo was added incorrectly.
- When introducing a new repository into an existing workstream, first clone or confirm the canonical `main` checkout, then add `wip/<stream>` with `git worktree add` so VS Code workspace and Source Control views stay consistent across repos.
- Local worktrees may use short-lived or medium-lived `wip/<stream>` branches to isolate active work.
- Rebase or selectively promote ready increments from `wip/<stream>` into `main` frequently.
- Workstream names should stay consistent across repos, workspace files, issue references, and acceptance criteria.

## Documentation Rule

- If the implementation meaningfully changes behaviour, protocol handling, runtime setup, testing, deployment, or standards interpretation, update `project-docs` in the same work cycle.
- Do not defer documentation updates to an unspecified later cleanup task.

## Testing Expectations

- Use repo-native deterministic checks as mandatory local gates.
- Keep pre-commit hooks fast and deterministic.
- Keep pre-push hooks repo-aware and meaningful.
- For the local issuer Python services, prefer Python 3.11 for `.venv` bootstrap so local runtime stays close to the current Docker packaging baseline; use 3.10 or 3.9 only as explicit fallback choices.
- If local Python runtime drift is detected, rebuild the affected `.venv` with `project-docs/scripts/bootstrap-local-python-venvs.sh` rather than patching around the drift inside repo code or cloud deployment scripts.
- While pull requests are not yet the primary delivery mechanism, `push` to `main` must still be treated as a controlled integration event with deterministic remote validation.
- Strengthen verifier-focused smoke and acceptance coverage as the Irish Life workstream evolves.

## AWS Deployment Principles

- Prefer GitHub OIDC to AWS over long-lived AWS keys.
- Keep build and deploy concerns separate.
- Treat environment-specific infrastructure as explicit, reviewable configuration.
- Do not embed AWS-specific assumptions into local-only orchestration without documenting the intended deployment path.
- For phase 1, use a single shared AWS environment named `test` and keep the local build as the effective development baseline.
- For phase 1, trigger cloud validation and deployment from `push` to `main` plus explicit manual workflows; pull request workflows can be added later once the build is mature.
- Keep application repository packaging logic separate from the dedicated infrastructure repository `instechsandbox-eudi-deploy`.
- Prefer reusable GitHub Actions workflows in `.github` and repo-local caller workflows in each application repository.
- Put infrastructure as code in `instechsandbox-eudi-deploy`, not in `.github`, `project-docs`, or the application repositories.
- Treat artifact publication as part of application packaging: service repos publish images, while `instechsandbox-eudi-deploy` consumes image references and performs environment deployment.
- Keep AWS environment logic centralized in `instechsandbox-eudi-deploy` rather than duplicating environment-specific AWS behaviour in application repositories or `.github`.
- Factor repeated artifact publication mechanics into reusable workflows in `.github`, with application repositories limited to thin caller workflows.
- Use Terraform in `instechsandbox-eudi-deploy` for the phase-1 AWS infrastructure baseline unless and until the documented deployment toolchain changes.
- When moving from image publication to ECS runtime scaffolding, prefer a separate low-cost runtime layer that consumes immutable image refs and keeps `desired_count = 0` by default until the cloud runtime configuration contract is explicitly documented and wired.
- For cloud-facing TLS, treat local self-signed certificates as a local-only development convenience. The cloud path should use explicit DNS and ACM-managed certificates unless a separately documented private trust model is required.
- When wiring ECS runtime configuration, keep plain settings in reviewed config and inject secrets through Parameter Store or Secrets Manager references rather than committing secret values or rebuilding images per environment.

## Security Constraints

- Keep local-only keys, certificates, JWKS files, and runtime artifacts out of version control.
- Do not weaken protocol or trust handling merely for convenience.
- Record any deliberate local-only exception in `project-docs`.

## Lessons Learned Process

- When a recurring lesson is discovered, propose an update to this working agreement or another canonical doc.
- Record reusable lessons in `docs/Engineering_Lessons_Log.md`.
- Prefer updating documented conventions over repeating the same mistake across chats.
- Do not silently mutate instructions without making the change visible in versioned docs.

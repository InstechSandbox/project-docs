# Engineering Lessons Log

## Purpose

Record recurring lessons that are worth turning into shared engineering guidance.

## Entry Template

### YYYY-MM-DD - Short lesson title

- Context:
- What happened:
- Reusable lesson:
- Follow-up doc or rule update:

## Seed Entries

### 2026-04-07 - Cloud deployment should extend the local packaging model, not fork it

- Context: The proof of concept is moving from a repeatable local build into GitHub Actions driven AWS deployment.
- What happened: The design review showed that the local wrappers were already thin enough to serve as a stable foundation, but tracked runtime JSON and SAN files were still being mutated in place for local host-specific setup.
- Reusable lesson: Preserve the local build as the engineering baseline, but converge local and cloud onto the same packaging contracts, generated runtime config, and reviewable deployment model instead of maintaining two separate systems.
- Follow-up doc or rule update: Record the single-environment `test` model, push-to-main trigger, Docker-first issuer direction, and generated-config requirement in the cloud deployment runbook and AI working agreement.

### 2026-03-31 - Local runtime artifacts must remain untracked

- Context: Local EUDI orchestration relies on certificates, JWKS files, and generated runtime assets that differ per machine.
- What happened: Several repositories required explicit ignore discipline and repeatable wrapper scripts to keep local artifacts out of source control.
- Reusable lesson: Encode local-only artifact rules in git hooks and docs rather than relying on memory.
- Follow-up doc or rule update: Keep local-only artifact checks in shared git hooks and repo guidance.

### 2026-03-31 - Forward references in local env files can break runtime assumptions

- Context: A derived `.env` value referenced another variable defined later in the file.
- What happened: `DEFAULT_FRONTEND=${FRONTEND_ID}` resolved incorrectly and broke the credential offer flow.
- Reusable lesson: Do not rely on forward references in local environment files when runtime behaviour depends on the resolved value.
- Follow-up doc or rule update: Prefer explicit values or validated generation scripts for critical local env fields.

### 2026-04-01 - New shared gates can expose pre-existing repo health debt

- Context: Shared pre-push hooks were introduced across the multi-repo workspace to enforce repo-native deterministic checks.
- What happened: Foundation-only commits that changed only `.github/copilot-instructions.md` were blocked in several repos by pre-existing Gradle, pytest, and ESLint failures unrelated to the changed files.
- Reusable lesson: When a change only introduces governance or documentation files outside the product runtime path, failing quality gates should be treated first as potentially pre-existing repository debt rather than as regressions caused by that change.
- Follow-up doc or rule update: If delivery needs require a temporary bypass, record a dedicated shared-hook bypass commit, track the affected repos in the gate debt backlog, and revert that specific commit once the repo-native gates are fixed.

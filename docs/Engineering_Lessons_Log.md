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
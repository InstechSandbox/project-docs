# Project Docs Guidance

- Use GPT-5.4 by default for standards-sensitive and cross-repo documentation work.
- Treat `docs/EIDAS_ARF_Implementation_Brief.md` and `docs/AI_Working_Agreement.md` as the canonical local guidance.
- This repo owns cross-repo runbooks, architecture notes, standards summaries, and working agreements.
- Avoid over-regurgitating ARF, eIDAS, or other published standards; summarize only what is needed locally, then cite and cross-reference the authoritative source for normative detail.
- If behaviour, architecture, environment setup, CI/CD, or test strategy changes anywhere in scope, update this repo in the same task.
- Record recurring lessons in `docs/Engineering_Lessons_Log.md` rather than rediscovering them repeatedly.
- Default Git flow in this workspace is local `wip/<stream>` commits promoted into protected default branches through reviewed pull requests; do not publish remote `wip/<stream>` branches unless explicitly requested.
- For the `cloud-build` workstream, keep guidance biased toward the lowest-cost architecture that still supports a public-internet end-to-end mobile credential request plus proof/verification demo.
- Call out when a proposed cloud design adds fixed or always-on cost, and prefer additive steps that defer those costs until they are necessary for the public demo target.

## Local Checks

- Validate shell scripts with `find scripts -name '*.sh' -print0 | xargs -0 -n1 bash -n`.

## Sensitive Areas

- Do not casually rewrite historical rationale in deployment or licensing notes.
- Keep the runbooks aligned with the actual repository-native commands.
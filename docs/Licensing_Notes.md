# Licensing Notes

This note captures practical engineering guidance for working with the six implementation repositories in the `InstechSandbox` EUDI insurance readiness proof of concept.

It is intended to reduce avoidable operational risk when publishing changes, distributing builds, or presenting the fork set publicly.

It is not legal advice.

## Current Repository License Snapshot

| Repository | License | Practical posture |
| --- | --- | --- |
| `eudi-app-android-wallet-ui` | `EUPL-1.2` | Usable for the current fork/reference implementation work, but more sensitive if modified binaries are redistributed |
| `eudi-srv-issuer-oidc-py` | `Apache-2.0` | Natural fit for public fork and reference implementation work |
| `eudi-srv-web-issuing-eudiw-py` | `Apache-2.0` | Natural fit for public fork and reference implementation work |
| `eudi-srv-web-issuing-frontend-eudiw-py` | `Apache-2.0` | Natural fit for public fork and reference implementation work |
| `av-srv-web-verifier-endpoint-23220-4-kt` | `Apache-2.0` | Natural fit for public fork and reference implementation work |
| `eudi-web-verifier` | `Apache-2.0` | Natural fit for public fork and reference implementation work |

The license file in each implementation repository is the authoritative license source for that repository.

## Practical Assessment

Based on the current fork set and preserved repository artifacts, there is no obvious sign that the present reference implementation work is inherently incompatible with the license mix.

The main engineering risk is not the existence of public forks. The main risk is careless handling of notices, modified distributions, or branding.

In practical terms:

- The five `Apache-2.0` repositories are well suited to open reference implementation work
- The `EUPL-1.2` wallet repository is workable, but deserves more care if modified application packages are distributed outside a private development flow
- The fact that these repositories are forks with local modifications does not by itself break the upstream licensing model

## Working Rules

Use the following rules as the default operating posture for this project.

1. Keep upstream license and notice files intact.
2. Preserve any existing attribution, notice, or file-header material that ships with upstream repositories.
3. Treat each repository as separately licensed unless its own license text says otherwise.
4. Keep documentation-repo licensing separate from implementation-repo licensing.
5. Record material local modifications in commit history and technical notes so derivative work is easy to explain.

## Distribution Cautions

The most important boundary is the difference between source-level collaboration and redistributed build artifacts.

- Public source forks with preserved notices are generally the lower-risk case in this project
- Redistributing a modified wallet APK deserves extra care because the wallet repository is under `EUPL-1.2`
- If binaries are shared outside the immediate development workflow, confirm that the corresponding source and required notices remain available in the manner required by the governing repository license
- If a release process becomes regular rather than ad hoc, document the release inputs and retained notices explicitly

## Notice And Header Preservation

Several repositories already contain compliance-relevant materials such as `NOTICE.txt`, `licenses.md`, or `FileHeader.txt`.

Those artifacts should be treated as part of the compliance surface, not as optional housekeeping.

At minimum:

- do not delete them casually
- do not replace them with generic project-level statements
- do not assume the docs repositories can override them

## Branding And Trademark Caution

License compliance is not the only exposure area.

Even where copyright licensing is acceptable, project names, logos, or implied affiliation can still create problems if presentation suggests endorsement by upstream maintainers or EU bodies where none exists.

When publishing publicly:

- describe the work as a forked reference implementation or local proof of concept
- avoid language that implies official status unless that status actually exists
- review visible names, logos, and organization descriptions with the same care as license files

## Operational Advice

For this project, the sensible default is:

1. Continue keeping the implementation repositories under their existing upstream licenses.
2. Keep `.github` and `project-docs` licensed only for their own content.
3. Avoid unnecessary binary redistribution from the wallet repository.
4. Preserve upstream notices and headers when making further changes.
5. Escalate to legal review only if distribution scope, branding, or commercial exposure changes materially.
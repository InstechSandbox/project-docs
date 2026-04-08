# Licensing Notes

This note captures practical engineering guidance for working with the current implementation repositories in the `InstechSandbox` EUDI insurance readiness proof of concept.

It is intended to reduce avoidable operational risk when publishing changes, distributing builds, or presenting the fork set publicly.

It is not legal advice.

## Current Repository License Snapshot

| Repository | License | Practical posture |
| --- | --- | --- |
| `eudi-app-android-wallet-ui` | `EUPL-1.2` | Usable for the current fork/reference implementation work, but modified tester builds must travel with source and retained notices |
| `eudi-app-ios-wallet-ui` | `EUPL-1.2` | Same EUPL posture as the Android wallet; suitable for PoC tester builds if source, notices, and modification records remain available |
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
- The two `EUPL-1.2` wallet repositories are workable, but deserve more care if modified application packages are distributed outside a private development flow
- The fact that these repositories are forks with local modifications does not by itself break the upstream licensing model

## Current InstechSandbox Tester Distribution Posture

For the current proof-of-concept work, InsTech intends to distribute only small-scale tester builds and to do so in a way that preserves the upstream license position rather than trying to narrow it.

The intended operating posture is:

- keep the corresponding source available in the `InstechSandbox` wallet forks for every distributed tester build
- preserve upstream `LICENSE.txt`, `NOTICE.txt`, and `FileHeader.txt` materials in the source forks
- publish a release note or sidecar record that states the build is modified by `InstechSandbox`, identifies the source commit, and records the modification date
- keep the mobile apps clearly framed as proof-of-concept or tester builds rather than official upstream or production releases
- retain a third-party dependency inventory and notice bundle for each distributed mobile build

This is an operational compliance posture, not a substitute for legal advice. The detailed mobile-app workflow is maintained in [Mobile App Distribution Compliance](Mobile_App_Distribution_Compliance.md).

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
- Redistributing a modified wallet APK or iOS tester build deserves extra care because both wallet repositories are under `EUPL-1.2`
- If binaries are shared outside the immediate development workflow, confirm that the corresponding source and required notices remain available in the manner required by the governing repository license
- If a release process becomes regular rather than ad hoc, document the release inputs and retained notices explicitly
- Treat TestFlight, direct APK sharing, and any other tester distribution channel as a real redistribution event for notice and source-availability purposes

## Notice And Header Preservation

Several repositories already contain compliance-relevant materials such as `NOTICE.txt`, `licenses.md`, or `FileHeader.txt`.

Those artifacts should be treated as part of the compliance surface, not as optional housekeeping.

At minimum:

- do not delete them casually
- do not replace them with generic project-level statements
- do not assume the docs repositories can override them
- for mobile tester builds, carry their content forward into the release record or sidecar notice bundle

## Third-Party Notice Handling

The top-level repository license is only part of the mobile distribution story.

Both wallet apps pull in additional third-party packages through their platform package managers, and those packages may carry their own notice requirements.

The current project posture is therefore:

- treat repo-level `LICENSE.txt` and `NOTICE.txt` as mandatory but not sufficient for mobile app redistribution
- maintain a current dependency inventory for the Android and iOS wallet repos
- ship or publish a third-party notice bundle alongside each tester release to the extent required by the shipped dependency set

The current baseline inventory and release workflow are documented in [Mobile App Distribution Compliance](Mobile_App_Distribution_Compliance.md).

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
3. For wallet tester builds, distribute only with corresponding source, retained notices, and a dependency notice record.
4. Preserve upstream notices and headers when making further changes.
5. Escalate to legal review only if distribution scope, branding, or commercial exposure changes materially.

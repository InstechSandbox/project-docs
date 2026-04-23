# Project Docs

This repository holds documentation that applies across the current implementation repositories in the `InstechSandbox` EUDI insurance readiness proof of concept.

This repository is a proof-of-concept reference implementation document set. It is intentionally shared so customers can build the repos, run them locally, deploy them to cloud test environments, and compare implementation experience. It is not production-hardening or production-operations guidance.

## Start Here

If you want to:

- build and run the reference implementation locally, start with [Local Build Runbook](docs/Local_Build_Runbook.md)
- understand what wallets mean for insurers operationally, start with [Insurer Readiness Pack](docs/Insurer_Readiness_Pack.md)
- understand the public cloud deployment shape, start with [Emerald Insurance Public Cloud Architecture](docs/Emerald_Insurance_Public_Cloud_Architecture.md)
- understand the cloud build, release, and deployment model, use [Cloud Build And Deployment Runbook](docs/Cloud_Build_Deployment_Runbook.md)
- install the wallet and run the public demo journeys, use [Stakeholder Wallet Demo Guide](docs/Stakeholder_Wallet_Demo_Guide.md)
- understand the standards and protocol profile choices behind the PoC, read [Reference Implementation Standards Summary](docs/Reference_Implementation_Standards_Summary.md)

## Core Documents

- [Insurer Readiness Pack](docs/Insurer_Readiness_Pack.md) - concise insurer-facing summary of what wallets enable, onboarding and AML implications, immediate actions, and Government-led environment considerations
- [Emerald Insurance Public Cloud Architecture](docs/Emerald_Insurance_Public_Cloud_Architecture.md) - public `test` environment architecture, AWS runtime boundaries, Mermaid diagrams, and verifier-first system context for the Emerald Insurance proof of concept
- [Local Build Runbook](docs/Local_Build_Runbook.md) - step-by-step local build, startup, smoke, wallet install, issuance, and verification flow across the six repositories
- [Cloud Build And Deployment Runbook](docs/Cloud_Build_Deployment_Runbook.md) - agreed first-phase business and technical operating model for GitHub Actions, artifact publication, release flow, AWS `test` deployment, and the `cloud-build` workstream
- [EIDAS ARF Implementation Brief](docs/EIDAS_ARF_Implementation_Brief.md) - local implementation guardrails for ARF alignment, protocol assumptions, trust boundaries, and verifier-first delivery
- [Reference Implementation Standards Summary](docs/Reference_Implementation_Standards_Summary.md) - concise map of the standards and profiles used in this PoC, where they are implemented across the repo set, and which delivery concessions remain explicit
- [AI Working Agreement](docs/AI_Working_Agreement.md) - canonical AI-assisted engineering rules, repo map, testing expectations, and docs-update policy
- [Emerald Insurance New Business Verifier Design](docs/Emerald_Insurance_New_Business_Verifier_Design.md) - business analysis, credential strategy, support-agent UX design, and pre-implementation architecture for the first Emerald Insurance verifier journey
- [Engineering Lessons Log](docs/Engineering_Lessons_Log.md) - reusable lessons captured as the project evolves
- [Repo Gate Debt Backlog](docs/Repo_Gate_Debt_Backlog.md) - tracked follow-up items for repo-native gates surfaced by the shared hooks
- [Local Deployment Notes](docs/Local_Deployment_Notes.md) - explains the fork-to-baseline commit set, the rationale behind the local deployment changes, and the coordinated baseline tags
- [Emerald Insurance Demo OBS Overlay](docs/Emerald_Insurance_Demo_OBS_Overlay.md) - simple browser-source overlay for end-to-end demo recordings with customer and agent screen labels
- [iOS Wallet Enablement Plan](docs/IOS_Wallet_Enablement_Plan.md) - initial repo scope, build path, smoke targets, and distribution preparation for the iOS workstream
- [Licensing Notes](docs/Licensing_Notes.md) - practical engineering guidance on the mixed-license repo set, notice preservation, and distribution cautions
- [Mobile App Distribution Compliance](docs/Mobile_App_Distribution_Compliance.md) - PoC tester-distribution rules for the Android and iOS wallet forks, including notice retention, source availability, and third-party notice handling
- [Mobile App Release Record Template](docs/Mobile_App_Release_Record_Template.md) - reusable template for Android APK and iOS TestFlight tester release records

## Repositories In Scope

- [eudi-app-android-wallet-ui](https://github.com/InstechSandbox/eudi-app-android-wallet-ui)
- [eudi-app-ios-wallet-ui](https://github.com/InstechSandbox/eudi-app-ios-wallet-ui)
- [eudi-srv-issuer-oidc-py](https://github.com/InstechSandbox/eudi-srv-issuer-oidc-py)
- [eudi-srv-web-issuing-eudiw-py](https://github.com/InstechSandbox/eudi-srv-web-issuing-eudiw-py)
- [eudi-srv-web-issuing-frontend-eudiw-py](https://github.com/InstechSandbox/eudi-srv-web-issuing-frontend-eudiw-py)
- [av-srv-web-verifier-endpoint-23220-4-kt](https://github.com/InstechSandbox/av-srv-web-verifier-endpoint-23220-4-kt)
- [eudi-web-verifier](https://github.com/InstechSandbox/eudi-web-verifier)

## Baseline Reference

The current stable local working baseline is tagged in each of the six currently validated runtime repositories as:

- `local-e2e-baseline-2026-03-27`

The iOS wallet fork is now in scope for enablement and licensing tracking, but it is not yet part of a coordinated stable runtime baseline tag.

The detailed tag-to-commit mapping is maintained in [Local Deployment Notes](docs/Local_Deployment_Notes.md).

## License Summary

The seven implementation repositories currently in scope do not use a single shared license.

- `eudi-app-android-wallet-ui` uses `EUPL-1.2`
- `eudi-app-ios-wallet-ui` uses `EUPL-1.2`
- `eudi-srv-issuer-oidc-py` uses `Apache-2.0`
- `eudi-srv-web-issuing-eudiw-py` uses `Apache-2.0`
- `eudi-srv-web-issuing-frontend-eudiw-py` uses `Apache-2.0`
- `av-srv-web-verifier-endpoint-23220-4-kt` uses `Apache-2.0`
- `eudi-web-verifier` uses `Apache-2.0`

The full context and repository-by-repository notes are maintained in [Local Deployment Notes](docs/Local_Deployment_Notes.md), [Licensing Notes](docs/Licensing_Notes.md), and [Mobile App Distribution Compliance](docs/Mobile_App_Distribution_Compliance.md).

## Why This Repo Exists

The organization profile README should stay short and act as an entry point.

This repository exists so the deeper technical narrative can live in one place without duplicating the same operational detail across the implementation READMEs.

The current documentation scope explicitly includes both the stable local baseline and the first-phase cloud build and deployment design.

## Licensing Note

This repository documents the cross-repository reference implementation and local deployment rationale.

See [LICENSE.md](LICENSE.md) for the license text that applies to this documentation repository.

The license file in each implementation repository is the authoritative license source for that repository.

Its license applies only to the content of this documentation repository. The implementation repositories remain governed by their own repository-specific licenses.

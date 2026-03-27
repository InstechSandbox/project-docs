# Project Docs

This repository holds documentation that applies across the six implementation repositories in the `InstechSandbox` EUDI insurance readiness proof of concept.

## Core Documents

- [Local Deployment Notes](docs/Local_Deployment_Notes.md) - explains the fork-to-baseline commit set, the rationale behind the local deployment changes, and the coordinated baseline tags

## Repositories In Scope

- [eudi-app-android-wallet-ui](https://github.com/InstechSandbox/eudi-app-android-wallet-ui)
- [eudi-srv-issuer-oidc-py](https://github.com/InstechSandbox/eudi-srv-issuer-oidc-py)
- [eudi-srv-web-issuing-eudiw-py](https://github.com/InstechSandbox/eudi-srv-web-issuing-eudiw-py)
- [eudi-srv-web-issuing-frontend-eudiw-py](https://github.com/InstechSandbox/eudi-srv-web-issuing-frontend-eudiw-py)
- [av-srv-web-verifier-endpoint-23220-4-kt](https://github.com/InstechSandbox/av-srv-web-verifier-endpoint-23220-4-kt)
- [eudi-web-verifier](https://github.com/InstechSandbox/eudi-web-verifier)

## Baseline Reference

The current stable local working baseline is tagged in each implementation repository as:

- `local-e2e-baseline-2026-03-27`

The detailed tag-to-commit mapping is maintained in [Local Deployment Notes](docs/Local_Deployment_Notes.md).

## License Summary

The six implementation repositories do not use a single shared license.

- `eudi-app-android-wallet-ui` uses `EUPL-1.2`
- `eudi-srv-issuer-oidc-py` uses `Apache-2.0`
- `eudi-srv-web-issuing-eudiw-py` uses `Apache-2.0`
- `eudi-srv-web-issuing-frontend-eudiw-py` uses `Apache-2.0`
- `av-srv-web-verifier-endpoint-23220-4-kt` uses `Apache-2.0`
- `eudi-web-verifier` uses `Apache-2.0`

The full context and repository-by-repository notes are maintained in [Local Deployment Notes](docs/Local_Deployment_Notes.md).

## Why This Repo Exists

The organization profile README should stay short and act as an entry point.

This repository exists so the deeper technical narrative can live in one place without duplicating the same operational detail across six separate READMEs.

## Licensing Note

This repository documents the cross-repository reference implementation and local deployment rationale.

See [LICENSE.md](LICENSE.md) for the license text that applies to this documentation repository.

Its license applies only to the content of this documentation repository. The six implementation repositories remain governed by their own repository-specific licenses.
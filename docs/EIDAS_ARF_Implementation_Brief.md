# EIDAS ARF Implementation Brief

## Purpose

This brief records the mandatory architecture and protocol guardrails for the InstechSandbox proof of concept. It is the local, versioned working summary that implementation agents and developers must apply before changing protocol-facing behaviour.

This document does not replace the EIDAS Architecture and Reference Framework. It narrows the project interpretation and makes the active constraints explicit for daily engineering work.

## Current Delivery Posture

- The current delivery focus is a verifier-first proof of concept, beginning with the Emerald Insurance branded verifier journeys.
- The wallet and issuer components are currently treated as reference-backed enabling components rather than production target products.
- The six forked EUDI repositories are being used as working reference implementations and integration anchors.
- Any change that departs from ARF-aligned behaviour must be called out explicitly in `project-docs` as a design choice, limitation, or temporary implementation concession.

## Relevant ARF Constraints

- The wallet, issuer, and verifier roles must remain clearly separated.
- Protocol-facing behaviour must align with the ARF interpretation of trust, credential issuance, presentation, and relying-party interaction.
- Privacy-preserving behaviour takes precedence over convenience shortcuts when there is a conflict.
- Verifier behaviour must avoid creating unnecessary data retention, correlation, or over-collection risk.
- The proof of concept may simplify non-core functions, but simplifications must not misrepresent normative trust or protocol responsibilities.

## Applicable Protocol Assumptions

### OpenID4VCI

- Issuance flows are treated as enabling capabilities for end-to-end verifier testing and demonstration.
- The current local issuer stack supports authorization code, pre-authorized code, PAR, PKCE, DPoP, and wallet attestation flows as the reference baseline.
- Issuer-facing changes should be minimized unless verifier delivery requires them.

### OpenID4VP

- The verifier proof of concept must keep request object generation, `request_uri` handling, and response processing aligned with OpenID4VP expectations.
- Presentation requests must remain explicit about requested claims and acceptable credential formats.
- Verifier-side UX changes must not silently mutate protocol semantics.

### SIOPv2

- Where verifier journeys rely on wallet-mediated identity assertions, SIOPv2 assumptions must be treated as normative protocol constraints, not UI details.
- Any reliance on self-issued identity behaviour must be documented when it affects verifier journey design or acceptance criteria.

## Trust Model Assumptions

- The wallet is the holder-facing agent that presents credentials and proofs.
- The issuer is the credential source for local issuance demonstrations.
- The verifier is the relying-party-facing component and the current primary product focus.
- Trust decisions must be evidence-based and aligned with ARF-compatible trust assumptions rather than hard-coded demo shortcuts wherever practical.
- Local demo certificates, local JWKS material, and development trust anchors are implementation aids and must not be treated as production trust models.

## Role Boundaries

### Wallet

- The wallet is treated as a reference-driven client for issuance and presentation.
- Wallet-side changes should be constrained to interoperability, local trust, or demonstration support unless a dedicated wallet workstream is approved.

### Issuer

- The issuer remains a dummy/reference-backed implementation for the current program phase.
- Issuer behaviour may be adjusted to maintain end-to-end interoperability, but issuer-side innovation is not currently the primary delivery objective.

### Verifier

- The verifier is the current primary delivery surface.
- Branded journey work, journey-specific UX, acceptance tests, and AWS deployment priorities should be organized around verifier outcomes.
- Verifier changes must continue to respect ARF and OpenID protocol obligations.

## Security And Privacy Constraints

- Do not over-request claims beyond what the target journey needs.
- Do not weaken trust, proof validation, or transport assumptions merely to simplify a demo.
- Keep local-only certificates, signing keys, JWKS files, and environment artifacts out of version control.
- Prefer deterministic, reviewable configuration changes over hidden runtime mutation.
- Treat logs, screenshots, fixtures, and test data as potentially sensitive if they contain identity-related payloads.

## Normative Versus Design Choices

The following distinction must be applied whenever a change is proposed.

### Normative

- ARF constraints and role boundaries
- OpenID4VCI, OpenID4VP, and SIOPv2 protocol requirements that affect correctness or interoperability
- Security and privacy obligations
- Trust and evidence handling expectations

### Project Design Choices

- Visual branding for Emerald Insurance verifier journeys
- Which verifier journeys are prioritized first
- How local orchestration, smoke testing, and demo environments are structured
- Which reference implementation components are treated as dummy enablers rather than product endpoints

## Engineering Rule

Before implementing any protocol-facing change, explicitly state:

1. which documents and constraints apply
2. whether the change is normative or a project design choice
3. what verifier, issuer, and wallet roles are affected
4. what documentation and tests must change with it

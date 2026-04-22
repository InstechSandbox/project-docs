# Insurer Readiness Pack

## Purpose

This note is a concise readiness pack for insurers assessing what EU Digital Identity Wallets could change in customer onboarding, identity verification, and AML-related evidence collection.

It is intentionally short and decision-oriented. It does not restate the ARF, eIDAS, or protocol specifications in full.

For normative and architecture detail, cross-reference:

- [EIDAS ARF Implementation Brief](EIDAS_ARF_Implementation_Brief.md)
- [Reference Implementation Standards Summary](Reference_Implementation_Standards_Summary.md)
- [Irish Life Public Cloud Architecture](Irish_Life_Public_Cloud_Architecture.md)
- [Irish Insurance Verifier FAQ](Irish_Insurance_Verifier_FAQ.md)

## 1. What Digital Identity Wallets Enable

Digital Identity Wallets let a customer share verifiable digital evidence directly from a wallet instead of sending scans, screenshots, or emailed documents.

For insurers, the practical shift is from collecting documents to requesting specific trusted claims for a business decision.

In the current proof of concept, that means a verifier can ask the wallet for a PID-based proof set and receive cryptographically verifiable evidence that can be matched against an insurance journey.

What this enables immediately:

- stronger evidence than ordinary uploaded document images
- selective disclosure of only the claims needed for the journey
- faster digital handoff from customer journey to insurer decisioning
- clearer automation points for evidence validation and match outcomes

What it does not do by itself:

- replace AML policy
- replace sanctions screening
- replace underwriting or fraud operations
- remove the need for insurer-side decision rules and exception handling

## 2. Implications For Insurance Onboarding And AML

The main operational implication is that onboarding and AML journeys can move from manual document inspection toward policy-based use of verifiable digital evidence.

For onboarding, that can reduce friction in steps that currently depend on the customer submitting identity and address evidence.

For AML-related checks, the immediate value is not that the wallet "does AML". The value is that it can provide better-quality identity and address evidence into the insurer's existing AML and customer-due-diligence controls.

In practice, insurers should expect four implications:

- evidence quality improves because the verifier checks signed digital evidence rather than relying on visual inspection alone
- claim minimisation becomes more realistic because the verifier can request only the claims needed for the decision
- exception handling becomes more explicit because mismatches can be surfaced as structured verifier outcomes
- trust policy becomes a first-class operating concern because the insurer must decide which issuers, credential types, and assurance levels are acceptable

For the current Irish Life proof of concept, the business-ready interpretation is narrower and deliberately practical:

- PID is currently the main identity evidence source
- address evidence is currently derived from PID address claims for the demo journeys
- verifier-side comparison and case-state progression are the primary delivery focus

That is a useful readiness baseline, but it should not be mistaken for a final production trust or AML operating model.

## 3. Immediate Actions Insurers Can Take

Insurers do not need to wait for the full future ecosystem to begin preparation.

The most useful immediate actions are:

1. identify one live journey where manual document checking is already causing friction
2. define the minimum claims genuinely needed for that decision
3. map how those claims would be compared against internal application or policy records
4. define what a successful match, mismatch, and manual-review outcome should mean operationally
5. identify which internal systems would need to consume a verifier result rather than raw uploaded documents
6. nominate owners across architecture, AML or compliance, digital journey, fraud, and operations

The technical preparation track should run in parallel:

1. assess verifier capability rather than wallet branding alone
2. define an issuer-trust and credential-acceptance policy approach
3. plan for both same-device and cross-device customer handoff patterns
4. treat auditability, consent evidence, and retention rules as design inputs from the start

The current proof of concept suggests that the fastest meaningful starting point is a verifier-led pilot for one controlled customer journey, not a broad enterprise platform program.

## 4. Anticipated Integration Considerations For Government-Led Environments

Government-led wallet environments are likely to improve assurance, issuer governance, and interoperability, but they will not remove insurer integration work.

Insurers should expect the main integration considerations to be:

- onboarding and governing trusted issuers under the applicable ecosystem rules
- aligning verifier policy with the credential formats and profiles supported in the target environment
- integrating verifier outcomes into onboarding, AML, claims, or servicing platforms
- handling customer exceptions, unsupported credentials, and manual fallback routes
- proving auditability and data-minimisation decisions to risk, compliance, and regulators

For this project specifically, the wallet and issuer stack used in the current proof of concept are reference-backed enabling components only.

The planned direction is that Government-led sandbox services will replace those supporting components in 2026. That means insurers should design toward stable verifier integration points and policy boundaries rather than over-fitting to the temporary dummy issuer and wallet stack used in this PoC.

## Recommended Executive View

The most grounded near-term interpretation is:

- wallets improve the quality and usability of customer evidence
- verifiers are the insurer-facing control point that matters most operationally
- onboarding and AML journeys can benefit early, but only when trust, policy, and downstream integration are designed explicitly
- the future Government-led environment should reduce ecosystem uncertainty, but it will not remove the need for insurer-side verifier architecture and operating decisions

## Related Reading

- [EIDAS ARF Implementation Brief](EIDAS_ARF_Implementation_Brief.md)
- [Reference Implementation Standards Summary](Reference_Implementation_Standards_Summary.md)
- [Irish Life Public Cloud Architecture](Irish_Life_Public_Cloud_Architecture.md)
- [Irish Insurance Verifier FAQ](Irish_Insurance_Verifier_FAQ.md)
- [Irish Life New Business Verifier Design](Irish_Life_New_Business_Verifier_Design.md)
- [Irish Life Existing Business Verifier Design](Irish_Life_Existing_Business_Verifier_Design.md)

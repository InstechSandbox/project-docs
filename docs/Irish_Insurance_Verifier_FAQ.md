# Irish Insurance Verifier FAQ

This FAQ is a short, business-facing guide for insurers and product teams that are evaluating verifier capabilities in the EU Digital Identity Wallet ecosystem.

It reflects the current working interpretation used in this project. It is aligned with the local [EIDAS ARF Implementation Brief](EIDAS_ARF_Implementation_Brief.md), the [AI Working Agreement](AI_Working_Agreement.md), and the current Emerald Insurance verifier design notes for [New Business](Emerald_Insurance_New_Business_Verifier_Design.md) and [Existing Business](Emerald_Insurance_Existing_Business_Verifier_Design.md).

It is not legal advice, certification guidance, or a substitute for the final ecosystem rulebooks that will apply in production.

## FAQ

### What problem does an EUDI wallet verifier solve for insurers?

It gives an insurer a standards-based way to ask a customer to share trusted digital evidence from their wallet instead of emailing scans or uploading screenshots. In practice, that can reduce manual document checking, shorten onboarding and claims journeys, and lower fraud exposure where the credential and issuer are trusted.

It does not replace underwriting, AML policy, sanctions screening, or policy-administration logic. It improves the quality and speed of the evidence that those processes consume.

### What is a verifier in simple terms?

A verifier is the relying-party system that asks the wallet for evidence, receives the presentation, validates it, and decides what to do next. In insurance terms, it is the component that sits between the customer journey and the insurer's internal business decisioning.

In this project, the verifier is the primary delivery surface. It is the part that generates the presentation request, handles wallet responses, and passes verified results into the Emerald Insurance journey logic.

### Is this only for government identity?

No. Government-issued identity is the most obvious starting point because it is high-value and widely understood, but the model is broader than that. The same wallet and verifier patterns can also support address, entitlement, employment, financial, and sector-specific credentials when those credential types are available in the ecosystem.

For insurers, that means the long-term opportunity is wider than identity proof alone. Identity is usually the first verifier use case, not the last one.

### What is the difference between mdoc and SD-JWT VC?

`mdoc` is the mobile document model that originated in the ISO mobile driving licence family and is designed for strong, device-bound credential presentation. It is a natural fit for high-assurance identity-style credentials and supports strong holder binding, including offline-oriented verification models in some deployments.

`SD-JWT VC` is a JSON-based credential format that supports selective disclosure by letting the holder reveal only chosen claims while preserving integrity. It is generally easier to fit into web-style and API-led ecosystems.

The short practical answer is: mdoc feels closer to a secure document container, while SD-JWT VC feels closer to a selectively disclosable web credential.

### Are both mdoc and SD-JWT VC relevant to eIDAS 2 wallets?

Yes. Verifier builders should expect both formats to matter. In this project's current verifier interpretation, PID presentations can be handled in both mdoc and SD-JWT VC forms, and the verifier design work already treats both as valid inputs.

The sensible implementation choice is not "pick one forever". It is usually "support the formats required by the credential profile and the journeys you care about".

### When would an insurer prefer one format over the other?

Choose mdoc when you need the profile that is most closely associated with high-assurance, document-style identity presentation and strong wallet-device binding. Choose SD-JWT VC when you want a flexible JSON-based credential flow with clear selective-disclosure behaviour and easier integration into web-oriented stacks.

In practice, insurers should expect ecosystem rules and credential availability to drive the decision more than personal format preference. A good verifier product should be able to cope with both where the target market requires it.

### How does a verifier know that a credential is genuine and has not been altered?

The verifier validates the cryptographic proof on the credential or presentation, checks that the issuer chain or trust anchor is acceptable, and confirms that the presentation matches the rules of the request. If a claim is altered, the integrity check fails.

In operational terms, a verifier is not "trusting what the customer typed". It is trusting signed evidence, presentation proofs, issuer trust material, and the verifier's own validation policy.

### How does a verifier know the issuer is trusted?

This is a trust-framework question, not just a file-format question. A verifier needs an accepted trust source for the issuer, such as the issuer's certificate chain, metadata, trust anchor, or another ecosystem-approved onboarding mechanism.

For European deployments, Qualified Trust Service Provider infrastructure and EU Trusted Lists may be part of that broader trust picture, but verifier builders should not assume that every runtime trust decision is made by a live Trusted List lookup alone. In practice, trust usually comes from a governed combination of ecosystem rules, issuer onboarding, certificates, metadata, and verifier policy.

### Practically, how does a government become a trusted issuer?

By joining the relevant ecosystem trust framework and publishing the required issuer identity, keys, certificates, and metadata in the way that framework expects. The exact operational path depends on the final ecosystem and national implementation rules, but the core point is consistent: trust is governed and auditable, not self-declared.

For verifier builders, the important design outcome is that issuer trust should be configurable, reviewable, and policy-driven. It should not be hard-coded as a demo shortcut.

### Can a verifier call the issuer directly every time it wants to check a credential?

Usually, no. The normal model is that the verifier validates the presented credential cryptographically and uses defined status or revocation mechanisms where the credential profile provides them. A verifier should not assume that every successful check requires a live callback to the issuer.

That matters for privacy as well as architecture. If a verifier always phones home to the issuer for each presentation, it creates unnecessary correlation risk and moves away from the user-controlled sharing model that the wallet ecosystem is trying to preserve.

### How are expiry and revocation handled?

Expiry is normally carried in the credential or its associated metadata and is checked by the verifier at the point of presentation. Revocation or suspension is handled through the status mechanism defined by the credential profile, which may use status lists, status endpoints, or related mechanisms.

The important practical point is that expiry and revocation are not the same thing. An insurer-grade verifier should be able to reason about both.

### What is selective disclosure, and why does it matter to insurers?

Selective disclosure means the customer can reveal only the claims needed for the transaction instead of handing over the whole credential. For example, a verifier may need confirmation of name, date of birth, and address, but not every other attribute in the wallet.

That matters because it supports data minimisation, reduces unnecessary retention risk, and gives the customer a clearer reason to trust the process. For insurers, it is both a privacy feature and a product-design advantage.

### What does an insurer need to build first if it wants to act as a verifier?

Start with one clear business decision that already depends on document checking today, such as onboarding, step-up verification, or a claims evidence check. Then design the verifier request around the minimum claims needed for that decision.

From a product standpoint, the first useful capability is not a giant wallet platform. It is a controlled verifier journey with clear claim requests, clear match rules, and a clear downstream decision outcome.

### What technical standards should a verifier product support first?

At minimum, verifier builders should expect OpenID4VP request and response handling, wallet-mediated identity assumptions associated with SIOPv2 where relevant, and explicit claim-query support such as DCQL where the chosen profile uses it. They should also be ready for both mdoc and SD-JWT VC credential handling if their target journeys span both.

On top of that, the verifier needs trust-anchor onboarding, issuer metadata handling, signature and proof validation, and credential status checks. The exact packaging will vary by product, but those capabilities are the core of a credible verifier stack.

### What infrastructure does an insurer need to run a verifier service?

At a minimum, it needs a verifier backend, a wallet handoff mechanism such as QR or same-device deep link, trust and cryptographic validation capability, and integration into internal systems that consume the verified result. It also needs operational controls for policy, logging, consent evidence, and auditability.

The key architectural point is that a verifier is not just a front end that shows a QR code. It is a policy and evidence-processing service.

### Does a verifier need to store the full credential?

Not by default. In many journeys, the better pattern is to store only the minimum evidence needed to support the business decision, the audit record, and any compliance obligations.

That is especially important in this project, where the ARF-aligned guidance is to avoid unnecessary data retention, correlation, and over-collection. Product teams should treat full-credential retention as a specific policy choice, not a harmless default.

### What level of assurance can insurers expect?

That depends on the credential type, the issuer, the wallet profile, and the governing trust framework. Government identity credentials such as PID are expected to offer strong assurance compared with ordinary document upload checks, but a verifier still needs to apply its own acceptance policy and not treat every credential as equally strong.

The right question is not "is the wallet high assurance?" in the abstract. It is "is this specific credential, from this issuer, under this trust framework, good enough for this business decision?"

### How could this reduce fraud in insurance?

It reduces some of the fraud that comes from forged documents, altered screenshots, replayed evidence, and weak manual checks. It also reduces opportunities for over-collection because the verifier can ask for only the claims it really needs.

It does not remove all fraud risk. It shifts the control point toward trusted digital evidence and stronger verifier policy.

### What are the biggest practical challenges for insurers?

The hard part is usually not the QR code or the wallet handoff. The harder work is deciding which claims are genuinely needed, mapping them into existing journeys, defining trusted issuers, handling mismatches and exceptions, and integrating the result into legacy decision systems.

There is also a change-management challenge: teams have to move from "collect documents and inspect them" to "request verifiable evidence and apply policy to the result".

### Should an insurer build its own verifier or buy one?

Build when verifier behaviour is strategically important, deeply embedded in internal systems, or part of the product differentiation. Buy when speed, managed standards upkeep, and lower implementation burden matter more than owning the full verifier stack.

Many insurers will end up with a hybrid approach: buy core verifier capability, then tailor the journey, policy, and integration layer around it.

## Related Reading

- [EIDAS ARF Implementation Brief](EIDAS_ARF_Implementation_Brief.md)
- [AI Working Agreement](AI_Working_Agreement.md)
- [Emerald Insurance New Business Verifier Design](Emerald_Insurance_New_Business_Verifier_Design.md)
- [Emerald Insurance Existing Business Verifier Design](Emerald_Insurance_Existing_Business_Verifier_Design.md)
- [Local Build Runbook](Local_Build_Runbook.md)

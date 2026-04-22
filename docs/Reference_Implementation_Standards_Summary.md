# Reference Implementation Standards Summary

## Purpose

This note explains which standards and profiles the current proof-of-concept reference implementation is intentionally aligned to, how that alignment is expressed in the running repository set, and where the current implementation still carries temporary delivery concessions.

It is a reference-implementation summary, not a certification claim, legal opinion, or formal conformance statement.

For normative detail, use the published standards and the local guardrail documents that already govern this project:

- [EIDAS ARF Implementation Brief](EIDAS_ARF_Implementation_Brief.md)
- [AI Working Agreement](AI_Working_Agreement.md)

## Current Posture

- This workspace is a verifier-first proof of concept.
- The verifier is the primary delivery surface.
- The wallet and issuer repositories are reference-backed enabling components used to prove end-to-end interoperability.
- The project aims to stay standards-aligned in protocol behaviour and trust shape where practical, while documenting any temporary implementation shortcut that exists for local or cloud demo delivery.

## How To Read This Note

- Treat the standards named here as the current active protocol and architecture baseline for this workspace.
- Treat the implementation mapping as a traceability aid, not as a substitute for reading the underlying design notes and runbooks.
- Treat the delivery concessions column as important. Those are the places where the current PoC is intentionally narrower, more local, or more operationally simplified than a production-grade deployment would be.

## Standards And Reference Implementation Mapping

| Standard or profile area | Why it matters here | Where it is implemented in the reference implementation | Current posture and delivery notes |
| --- | --- | --- | --- |
| eIDAS 2 / ARF role model | Keeps wallet, issuer, and verifier responsibilities separated and prevents demo shortcuts from misrepresenting trust responsibilities | Cross-repo architecture and engineering guardrails in [EIDAS ARF Implementation Brief](EIDAS_ARF_Implementation_Brief.md); verifier-first journey design in [Emerald_Insurance_New_Business_Verifier_Design.md](Emerald_Insurance_New_Business_Verifier_Design.md) and [Emerald_Insurance_Existing_Business_Verifier_Design.md](Emerald_Insurance_Existing_Business_Verifier_Design.md) | Applied as a working interpretation for the PoC. This is not a claim that the repos constitute a certified ARF-conformant product set. |
| OpenID4VCI | Provides the credential issuance baseline needed to put test credentials into the reference wallets before verifier demonstrations | Authorization and token server behaviour in `eudi-srv-issuer-oidc-py`; issuer backend and formatter path in `eudi-srv-web-issuing-eudiw-py`; issuer frontend offer and metadata path in `eudi-srv-web-issuing-frontend-eudiw-py`; wallet issuance clients in `eudi-app-android-wallet-ui` and the iOS wallet workstream | Treated as an enabling capability for verifier delivery rather than the primary product target. Local and cloud runbooks document operational fixes needed to keep the current issuer path interoperable. |
| OpenID4VP | Defines verifier request-object generation, `request_uri` retrieval, wallet handoff, and wallet response processing | Verifier backend request creation, transaction initialization, and response handling in `av-srv-web-verifier-endpoint-23220-4-kt`; wallet handoff and journey orchestration in `eudi-web-verifier`; wallet presentation clients in `eudi-app-android-wallet-ui` and the iOS wallet workstream | This is one of the most important protocol surfaces in the current PoC. Behaviour here should be treated as standards-sensitive and should not be changed casually for UX convenience. |
| SIOPv2 assumptions | Covers wallet-mediated identity assumptions that sit close to verifier request and response handling | Reflected in the local standards brief and in wallet-mediated verifier flows across the verifier backend, verifier UI, and wallet integrations | Applied as a protocol constraint where relevant to wallet-mediated identity flows. The project docs intentionally describe the assumptions that matter locally rather than restating the whole standard. |
| DCQL | Defines how the verifier asks for explicit claim sets and acceptable credential shapes | Claim-query construction in `av-srv-web-verifier-endpoint-23220-4-kt`; journey-specific request design in [Emerald_Insurance_New_Business_Verifier_Design.md](Emerald_Insurance_New_Business_Verifier_Design.md) and [Emerald_Insurance_Existing_Business_Verifier_Design.md](Emerald_Insurance_Existing_Business_Verifier_Design.md) | Current Emerald Insurance journeys rely on explicit claim queries. Some query details are shaped by current wallet interoperability constraints and are documented as such in the journey design notes. |
| SD-JWT VC | Supports the current preferred web-native PID proof path for the Emerald Insurance verifier journeys | PID issuance and formatting in the issuer stack; SD-JWT VC storage and proof generation in the wallets; SD-JWT validation and claim reconstruction in the verifier backend; cloud demo path in [Stakeholder_Wallet_Demo_Guide.md](Stakeholder_Wallet_Demo_Guide.md) | SD-JWT VC is currently the preferred target format for Emerald Insurance web journeys. The docs also record active trust-shape and certificate-handling constraints that affect successful SD-JWT proof validation. |
| mdoc / ISO 18013-style mobile document model | Provides the document-style credential path and fallback format already proven in the reference stack | mdoc issuance signer-chain handling in the issuer backend and shared scripts; mdoc storage and proof generation in the wallets; mdoc acceptance in the verifier backend | mdoc remains an important supported format and a fallback path for delivery risk control. Local signer-chain generation is intentionally described as standards-aligned plumbing for PoC interoperability, not production PKI. |
| Trust anchors, issuer-chain handling, and verifier trust policy | Ensures the verifier accepts only evidence from explicitly trusted issuers and that demo trust does not silently replace governed trust decisions | Trust configuration and issuer-chain use in `av-srv-web-verifier-endpoint-23220-4-kt`; issuer certificate material and signer-chain behaviour in `eudi-srv-web-issuing-eudiw-py`; wallet trust bootstrap and local cert distribution across the wallet repos; detailed operational notes in [Local_Build_Runbook.md](Local_Build_Runbook.md), [Cloud_Build_Deployment_Runbook.md](Cloud_Build_Deployment_Runbook.md), and [Engineering_Lessons_Log.md](Engineering_Lessons_Log.md) | This is implemented, but it is also where many current PoC concessions live. Local roots, generated signer chains, and emergency cloud trust settings are implementation aids, not a production trust framework. |
| Data minimisation and privacy-preserving verifier behaviour | Keeps verifier requests and evidence handling aligned with the ARF direction of minimum necessary data use | Claim selection and comparison rules in the Emerald Insurance verifier designs; verifier-side evidence handling constraints in [EIDAS_ARF_Implementation_Brief.md](EIDAS_ARF_Implementation_Brief.md) | The project explicitly treats over-collection and unnecessary retention as risks. Journey design and matching logic should remain tied to minimum viable claim requests for the business decision. |

## Repository View

The standards mapping above resolves to the current repositories as follows.

| Repository | Primary standards-facing responsibility in this workspace |
| --- | --- |
| `av-srv-web-verifier-endpoint-23220-4-kt` | OpenID4VP request creation, `request_uri` handling, wallet response processing, verifier-side proof validation, issuer trust handling, and journey-specific claim matching |
| `eudi-web-verifier` | Wallet handoff UX, same-device and cross-device verifier entry points, and Emerald Insurance journey orchestration that must stay aligned with the verifier backend contract |
| `eudi-srv-issuer-oidc-py` | OpenID4VCI-adjacent authorization and token server behaviour used by the local and public issuance flows |
| `eudi-srv-web-issuing-eudiw-py` | Issuer backend behaviour for credential issuance, formatter integration, signer material use, and credential metadata/runtime contracts |
| `eudi-srv-web-issuing-frontend-eudiw-py` | Issuer offer UX and the frontend path that exposes credential choices and issuer metadata to the wallet |
| `eudi-app-android-wallet-ui` | Reference wallet behaviour for issuance, storage, and proof presentation against the current verifier and issuer stacks |
| iOS wallet workstream | Parallel reference wallet path for iPhone enablement, with the same issuance and presentation goals under stricter platform constraints |

## Current Implementation Concessions To Keep Explicit

The current reference implementation is intentionally narrower than a production deployment in several places.

- Local trust roots, generated signer chains, and local certificate distribution are PoC interoperability aids.
- Some current query shapes and request details are influenced by present wallet interoperability behaviour rather than by abstract protocol minimalism alone.
- The cloud demo still carries temporary trust-shape constraints that are documented in the deployment runbook and lessons log.
- The issuer and wallet components are being used as enabling reference implementations for verifier delivery, not as finalized production products.

Those concessions are acceptable only when they are documented, reviewable, and clearly separated from the project's normative protocol intent.

## When To Update This Note

Update this summary when any of the following change:

- the active list of standards or profiles the project claims to align with
- the repository that owns a standards-facing responsibility
- the preferred credential format or fallback strategy for the verifier journeys
- the trust model assumptions or trust-material shape used in local or cloud demos
- any temporary implementation concession that could otherwise be mistaken for the intended long-term design

## Related Reading

- [EIDAS ARF Implementation Brief](EIDAS_ARF_Implementation_Brief.md)
- [AI Working Agreement](AI_Working_Agreement.md)
- [Emerald_Insurance_New_Business_Verifier_Design.md](Emerald_Insurance_New_Business_Verifier_Design.md)
- [Emerald_Insurance_Existing_Business_Verifier_Design.md](Emerald_Insurance_Existing_Business_Verifier_Design.md)
- [Local_Build_Runbook.md](Local_Build_Runbook.md)
- [Cloud_Build_Deployment_Runbook.md](Cloud_Build_Deployment_Runbook.md)
- [Engineering_Lessons_Log.md](Engineering_Lessons_Log.md)

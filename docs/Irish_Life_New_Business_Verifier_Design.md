# Irish Life New Business Verifier Design

## Purpose

This document records the business analysis, credential analysis, implementation brief, and proposed technical design for the first Irish Life verifier journey before product code changes begin.

It is intentionally design-first. It should be reviewed before verifier UI, verifier backend, or issuer metadata changes are implemented.

## Applicable Constraints

- The project constraints in [EIDAS_ARF_Implementation_Brief.md](EIDAS_ARF_Implementation_Brief.md) apply.
- The delivery and documentation rules in [AI_Working_Agreement.md](AI_Working_Agreement.md) apply.
- This is a verifier-first delivery.
- Protocol-facing behaviour must remain aligned with OpenID4VP and DCQL.
- Issuer changes are allowed only where verifier delivery needs them and should stay metadata-driven where possible.

## Business Analysis

### Business Context

Irish Life New Business currently relies on AML checks that require:

- proof of identity
- proof of address

The target journey demonstrates how a wallet-based verifier flow can replace manual collection of emailed documents.

### Current Flow

1. Customer submits customer information.
2. Support Agent manually sets up the new business policy on the system.
3. AML is triggered.
4. Support Agent requests proof of identity and proof of address by email.
5. Customer emails the documents.
6. Support Agent manually checks that the documents match the details previously submitted.
7. AML status is logged on the system.
8. Customer is notified.

### Proposed Flow

1. Customer submits customer information.
2. Support Agent system records that the new business policy has been set up.
3. AML is triggered.
4. Support Agent system invites the customer by email, with future extension to SMS, to provide proof of identity and proof of address using the wallet.
5. Customer opens the invitation on mobile and shares the required wallet credentials.
6. Support Agent system receives the proofs and verifies them.
7. Support Agent system checks the proofs against the new business application.
8. AML status is logged on the system.
9. Customer is notified.

### Demo Interpretation

For the first demo, the verifier solution should be treated as a dual-surface verifier product.

It should include:

- a support-agent-facing orchestration surface
- a customer-facing proof-sharing surface
- a dummy new-business case state
- an invite action that sends a real email where practical
- wallet proof collection and verification
- dummy but visible post-verification processing states for:
  - proof match against application
  - AML status logged
  - customer notified

For Journey 1, the support-agent surface is the primary orchestration surface.

The customer-facing surface is still required because the customer may:

- open an emailed deep link on mobile
- visit a web page and scan a QR code instead

This separation should be treated as a deliberate architectural requirement so the same verifier product can later support both agent and customer journeys for Existing Business Claims.

## Journey Decisions

### Confirmed

- Journey name: New Business
- Primary user: prospective customer, initiated from a support-agent workflow
- Product surface: Irish Life branded dual-surface verifier product
- Entry structure: new Irish Life journey selector with this journey as the first implemented route
- Future placeholder: Existing Business Claims journey
- Result handling: hard fail with visible reason on-screen
- Matching policy: exact-after-normalization

### Journey Starting Points

The verifier should provide clear journey starting points for both roles.

- Agent starting point: Irish Life New Business case orchestration page
- Customer starting point: Irish Life proof-sharing page, reachable by emailed deep link or by scanning a QR code from a browser page

These starting points should be explicit in the verifier UI rather than hidden inside the generic developer-oriented request builder flow.

### Current Placeholder For Future Journey

The landing experience should visibly reserve a second journey slot for Existing Business Claims without implementing that flow yet.

## Credential Analysis

### Verified Current Verifier Support

The current verifier stack already supports:

- PID in mdoc and SD-JWT VC forms
- multi-credential DCQL requests
- decoded credential display in the verifier UI

### Verified Current Issuer Metadata

The local issuer metadata was checked in the cloned repositories.

Verified available credentials include:

- PID mdoc
- PID SD-JWT VC
- POR mdoc
- POR SD-JWT VC
- MDL mdoc
- Photo ID mdoc
- Tax SD-JWT VC
- other sector credentials

### Important Finding

In the issuer repository, `por` means Power Of Representation, not Proof Of Residence.

Therefore it must not be used as the Irish Life proof-of-address credential.

### Verified PID Capability

The existing PID metadata already carries identity and address-related claims, including:

- family name
- given name
- birth date
- place of birth
- resident address fields
- nationality or nationalities
- personal administrative number
- issuing authority
- issuance and expiry dates
- portrait or picture

### Address-Capable Existing Credentials

The current issuer metadata includes address-related claims in several credentials, including:

- PID
- MDL
- Photo ID
- Tax
- HIID matching fields

However, none of the existing non-PID credentials is a clean semantic fit for Irish Life proof of address.

Using Tax, MDL, Photo ID, or HIID as proof of address would blur business meaning and would be harder to justify in a standards-sensitive demo.

### Expiry Model Observation

The currently available PID metadata exposes validity at credential level, not at address-field level.

That means the current framework and metadata support:

- credential issuance date
- credential expiry date
- verifier-side validation that the credential is expired or not expired

They do not currently support a distinct issuer-attested expiry that applies only to the address claim inside PID.

If field-level expiry is ever required, that would need to be modeled explicitly in the credential design rather than inferred by verifier policy.

## Risk Resolution

### Original Risk

The original risk was treating PID as both:

- proof of identity
- recent proof of address

while also applying a separate 90-day freshness rule to the address evidence.

PID issuance or expiry does not necessarily prove that the address evidence itself is recent enough for Irish Life AML purposes.

### Current Design Direction

For the current implementation increment:

- POI credential: PID
- POA evidence: address claims inside the existing PID credential

This is a delivery decision for the current sandbox preparation window.

It avoids creating a new address credential before the Government of Ireland sandbox credential set is confirmed.

### Result

This keeps the verifier flow aligned with currently available credentials while preserving the option to introduce a dedicated address credential later if the sandbox profile requires one.

## Credential Recommendation

### POI Credential

Use PID.

Expected business fields:

- surname -> `family_name`
- forename -> `given_name`
- date of birth -> `birth_date` or `birthdate` depending format
- place of birth -> `place_of_birth`
- sex -> `sex`
- nationality -> `nationality` or `nationalities`
- PPS number -> `personal_administrative_number`
- picture -> `portrait` or `picture`

### POA Credential

Do not build a separate POA credential in this increment.

Use the existing address claims inside PID as the current proof-of-address evidence for the journey.

Expected business fields:

- full formatted address where available
- structured address fields required for local matching: `street_address`, `locality`, `region`, `postal_code`
- credential issuance date
- credential expiry date
- issuing authority

The verifier should fail the proof if the presented PID is expired.

This expiry check is applied at credential level.

It is not currently modeled as an address-only expiry rule.

### Issuer Strategy

Reuse the existing issuer framework and metadata pattern.

Do not add a new POA credential in this increment.

Revisit the dedicated-address-credential question when the Government of Ireland sandbox confirms the target credential set and sandbox issuance approach.

## Format Recommendation

### Strategic View

SD-JWT VC is the preferred target format for this journey because it is the more web-native and future-facing option for browser-mediated, remote, and API-rich journeys.

That makes it the stronger fit for:

- emailed deep links
- customer-facing browser entry points
- future multi-surface verifier journeys
- likely longer-term interoperability direction

MSO mdoc remains the fallback option because it is already proven in the current local build and can be used if SD-JWT interoperability blocks delivery.

### Recommendation

For the first Irish Life New Business demo:

- target SD-JWT VC first
- keep the journey, UI routing, and backend orchestration format-agnostic
- preserve an mdoc fallback path if SD-JWT blocks timely delivery

This is the preferred delivery posture because it balances future direction with demo safety.

## Support Agent System Design

### Scope

For the demo, the verifier solution should present two distinct but connected UI surfaces.

The support-agent surface should include the following visible states:

1. New business policy set up on system
2. AML triggered
3. Invite customer to provide proof of identity and proof of address using wallet
4. Proofs received
5. Proofs verified
6. Proofs matched against application
7. AML status logged on system
8. Customer notified

The customer surface should include:

1. a route reached from email deep link
2. a browser page suitable for QR-based handoff
3. proof-sharing status
4. final completion or failure state

### Interpretation

The current verifier UI should therefore evolve into a dual-surface product.

For Journey 1, the orchestration, case status, invitation, and final decision experience should be framed primarily around the support-agent surface.

The customer-facing route remains a first-class part of the product rather than a side effect of the protocol flow.

## Email And Invite Requirement

### Requirement

The demo should send a real email if practical.

At the end of a successful New Business process, the system should also send a confirmation email to the customer.

### Design Implication

This should be implemented server-side, not directly from the Angular frontend.

Recommended approach:

- Support Agent UI triggers an invite action
- verifier backend creates or records a demo case state and generates the wallet deep link
- verifier backend sends email through configurable SMTP or an email API provider
- verifier backend sends a completion confirmation email after the process reaches the completed state

### Demo-Safe Fallback

If real email cannot be configured immediately, the backend should still produce:

- the exact invite email content
- the deep link
- a visible sent-state in the Support Agent system

But the preferred path remains real email.

## Proposed Technical Design

## Implemented Flow Snapshot

The current implementation now includes:

- an Irish Life journey selector at `/irish-life`
- an agent route at `/irish-life/new-business/agent`
- a customer entry route at `/irish-life/new-business/customer`
- a case-specific customer route at `/irish-life/new-business/customer/:caseId`
- backend case endpoints under `/ui/irish-life/new-business/cases`

The generic verifier routes remain available, but the default application entry point now redirects to the Irish Life journey selector.

### Frontend

In `eudi-web-verifier`:

- add an Irish Life journey selector landing page
- add a New Business support-agent route
- add a New Business customer-facing route
- add a visible placeholder tile for Existing Business Claims
- add clear role-based starting points for agent and customer
- add a journey-specific request builder for the New Business flow
- do not force this journey through the generic claim picker UI
- add support-agent status panels for the dummy case lifecycle
- add customer-facing proof-sharing and completion screens
- add proof summary views after wallet response

Implemented route set:

- `/irish-life`
- `/irish-life/new-business/agent`
- `/irish-life/new-business/customer`
- `/irish-life/new-business/customer/:caseId`

### Verifier Backend

In `av-srv-web-verifier-endpoint-23220-4-kt` or an adjacent backend integration layer:

- add invite creation support
- add email dispatch support
- add completion confirmation email dispatch support
- store or simulate demo case state
- record post-verification decision state
- expose status needed by the Support Agent UI
- expose status needed by the customer-facing flow

The existing OpenID4VP transaction initialization and wallet response handling should remain the protocol base.

Implemented backend endpoint set:

- `POST /ui/irish-life/new-business/cases`
- `GET /ui/irish-life/new-business/cases/{caseId}`
- `POST /ui/irish-life/new-business/cases/{caseId}/invite`
- `POST /ui/irish-life/new-business/cases/{caseId}/complete`

The backend stores case state in memory for the current demo implementation.

### Issuer Backend

In `eudi-srv-web-issuing-eudiw-py`:

- keep existing PID metadata
- do not add a dedicated POA credential in this increment
- keep open the option to add one later if the sandbox credential set requires it

### Authorization Server

`eudi-srv-issuer-oidc-py` is expected to remain mostly unchanged unless the new credential introduction requires issuer-flow metadata or auth-detail adjustments.

## DCQL Design

For this increment, the New Business presentation request should request one PID credential and the subset of identity and address claims needed for the journey.

Use:

- one credential query for PID
- claims for identity matching and address matching
- credential-level expiry validation on the presented PID

If a dedicated POA credential is introduced later, the DCQL design can evolve to a two-credential request at that point.

This keeps the current implementation aligned with the available sandbox-ready credential set.

## Validation Design

The verifier should validate:

- the presentation and proof as normal
- the required PID claims are present
- the claims match the new business application after normalization
- the presented PID is not expired

The current implementation should not attempt to enforce address-specific expiry independently from credential expiry because that is not modeled in the current credential design.

The implemented customer flow validates the presented PID, checks the required identity and address fields against the case data after normalization, and fails the case if the PID is expired or the required fields do not match.

## Matching Rules

Use exact-after-normalization.

Normalization should at minimum cover:

- trimming leading and trailing whitespace
- collapsing repeated internal whitespace
- case normalization where appropriate
- punctuation normalization for simple address formatting differences

This should be applied before exact comparison against the new business application data.

## Demo Scope

### In Scope For First Increment

- branded Irish Life dual-surface verifier UI
- journey selector and New Business route
- customer-facing proof-sharing route
- dummy new-business case state
- invite action and email path
- successful completion confirmation email
- wallet handoff
- proof summary
- hard-fail reasons
- dummy post-verification status progression
- placeholder for Existing Business Claims

### Out Of Scope For First Increment

- real policy administration system integration
- real AML decision engine integration
- real downstream customer notification integration beyond demo simulation
- dedicated proof-of-address credential introduction
- Existing Business Claims implementation

## Runtime Configuration

The current implementation introduces two important verifier backend runtime settings:

- `verifier.irishlife.customerBaseUrl`
- `verifier.mail.from`

The customer base URL is used for:

- the emailed customer proof link
- same-device wallet redirect back into the customer flow

The mail sender configuration relies on standard Spring mail settings, including:

- `spring.mail.host`
- `spring.mail.port`
- `spring.mail.username`
- `spring.mail.password`
- SMTP auth and TLS properties as needed

Without working SMTP configuration, the backend will keep the case flow running but will report invite and completion emails as not sent.

## Documentation Follow-Up

When implementation starts, update:

- this design note as decisions are confirmed
- local runbook if issuer setup or email setup changes
- deployment notes if new runtime dependencies are introduced
- engineering lessons if the new credential path exposes reusable patterns or pitfalls

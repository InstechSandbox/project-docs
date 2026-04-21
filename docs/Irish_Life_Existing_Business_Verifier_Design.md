# Irish Life Existing Business Verifier Design

## Purpose

This document records the implemented business interpretation, journey decisions, and technical design for the Irish Life Existing Business withdrawal verifier journey.

It sits alongside the New Business design and reuses the same local verifier stack, wallet proof pattern, and protocol constraints.

## Applicable Constraints

- The project constraints in [EIDAS_ARF_Implementation_Brief.md](EIDAS_ARF_Implementation_Brief.md) apply.
- The delivery and documentation rules in [AI_Working_Agreement.md](AI_Working_Agreement.md) apply.
- Protocol-facing behaviour remains aligned with OpenID4VP and DCQL.
- The Existing Business journey reuses the same PID proof set as the New Business journey.
- Irish Life branding and shared verifier behaviour should stay centralized rather than duplicated where practical.

## Business Interpretation

### Business Context

Irish Life Existing Business withdrawals, such as a Savings & Investments release, are used here as a simplified step-up verification journey.

The wallet does not replace policy administration, AML systems, or payment systems. Instead, it proves customer-held identity attributes that can be checked against an internal Irish Life policy record before an automated demo decision is recorded.

### Implemented Demo Flow

1. Customer opens the Existing Business customer journey from an already-authenticated policy context.
2. The verifier immediately resolves the demo policy to a hard-coded internal record and shows the prepopulated policy details on screen.
3. The verifier creates the withdrawal case and immediately starts the wallet proof request with no agent intervention.
4. The local demo continues to use supported policy number `12345678` behind that prepopulated view.
5. The agent workspace is notified and acts only as a read-only monitor for case progress.
6. The customer provides PID proof using the wallet.
7. The verifier validates PID and compares it with the internal policy record.
8. The verifier records a dummy AML lookup miss.
9. The verifier records a policy-application match after proof verification succeeds.
10. The verifier records an automated approval decision.
11. The agent workspace is notified as the case progresses through those stages.

### Journey Ownership Decision

- The customer drives the journey.
- The agent UI is intentionally a monitoring surface only.
- There is no agent-side case creation or invite action in the target Existing Business demo.

## Demo Policy Record

The current local demo supports one policy number only.

- Supported policy number: `12345678`
- Product: `Savings & Investments withdrawal`
- Withdrawal amount: `EUR 25,000`
- Destination account suffix: `6789`
- Expected given name: `Patrick`
- Expected family name: `Murphy`
- Expected birth date: `1980-04-12`
- Expected address: `1 Main Street, Dublin, Leinster, D02 XY56`

Any other policy number is rejected immediately and no case is created.

## Product Surface

The verifier remains a branded product with aligned customer and agent views.

It includes:

- a customer-facing withdrawal request and proof-sharing surface
- an agent-facing read-only claims monitoring workspace
- explicit status progression for the case lifecycle
- explicit notification events visible to the agent
- wallet proof collection and verifier-side proof validation
- visible automated post-proof processing states for:
  - policy application match
  - AML miss
  - automated release decision

## Technical Design

### Frontend

The verifier UI includes:

- an Existing Business agent route at `/irish-life/existing-business/agent`
- an Existing Business customer start route at `/irish-life/existing-business/customer`
- an Existing Business customer case route at `/irish-life/existing-business/customer/{caseId}`
- current Emerald Insurance branding on the customer-facing and agent-facing UI
- shared PID validation helpers reused from the Irish Life proof comparison path

Frontend behaviour now follows these rules:

- the customer start route creates the demo case automatically and routes immediately into the case page
- the case page shows the prepopulated policy details instead of a search form
- the case page auto-starts the proof handoff when an active wallet request exists
- the agent page lists all in-memory Existing Business cases and automatically expands the active one where possible

### Backend

The verifier backend exposes a dedicated Existing Business case API under:

- `/ui/irish-life/existing-business/cases`
- `/ui/irish-life/existing-business/cases/{caseId}`
- `/ui/irish-life/existing-business/cases/{caseId}/invite`
- `/ui/irish-life/existing-business/cases/{caseId}/complete`

Current backend behaviour:

- `POST /cases` accepts only `policyNumber`
- demo policy resolution is owned server-side
- case creation auto-starts the wallet proof request
- proof comparison runs against the resolved internal policy record, not against customer-entered or agent-entered comparison fields
- the in-memory store also supports list retrieval for the monitoring dashboard

### Case Lifecycle

The Existing Business status progression models the following states:

1. withdrawal request received
2. automated checks started
3. proof invite sent
4. proofs received
5. proofs verified
6. policy application matched
7. AML record not found
8. automated decision recorded
9. completed or failed

`CUSTOMER_NOTIFIED` remains in the type model for compatibility but is not a required milestone in the current customer-driven demo flow.

### Agent Notifications

The monitoring workspace shows explicit notifications for milestones such as:

- withdrawal request received
- automated checks started
- proof requested
- proof submitted
- proofs verified
- AML check completed
- decision ready
- manual review required on failure

## Reuse Strategy

This journey intentionally reuses the New Business building blocks that are genuinely common:

- Irish Life visual branding
- PID proof request profile
- customer PID validation logic
- same-device and QR entry behaviour
- case-state rendering patterns

This journey keeps its own business-specific artifacts separate:

- policy-number lookup rule
- withdrawal-specific statuses
- withdrawal-specific notification events
- read-only monitor behaviour for the agent workspace

## Validation Expectations

Local validation for this journey should cover:

- route accessibility from the Irish Life journey selector
- customer start page rendering and policy-number submission
- rejection of unsupported policy numbers
- automatic wallet proof initialization after supported policy submission
- wallet proof handoff by QR and same-device deep link where practical
- successful PID verification path for policy `12345678`
- visible policy-match and AML-miss states
- read-only agent monitor updates without customer-page intervention
- completed and failed terminal states

## Current Implementation Snapshot

The current workstream implementation includes:

- customer-owned Existing Business case creation keyed by policy number
- server-side hard-coded policy resolution for policy `12345678`
- automatic proof initialization as part of case creation
- a dedicated verifier backend case API under `/ui/irish-life/existing-business/cases/**`
- a dedicated Existing Business in-memory case store and lifecycle model
- a read-only Existing Business monitoring workspace that lists all cases
- shared Irish Life frontend types, PID validation helpers, and theme styling used across both Irish Life journeys

## Runtime Notes

- The Existing Business happy path is only expected to succeed when the issued PID matches the hard-coded policy record above.
- The local address should therefore continue to use `1 Main Street, Dublin, Leinster, D02 XY56`.
- The customer journey no longer depends on an emailed invite to begin proof sharing.
- The wallet request stays JWT-first, but current wallet interoperability in this workspace requires the initial PID DCQL query to include the address claims as well as the identity claims.
- The request should also emit an explicit single-entry `credential_sets` clause for the PID query so the current wallet can map the stored SD-JWT PID to the requested document set during presentation matching.
- The current working request shape is therefore the full PID claim set, including address claims, plus the single-entry `credential_sets` clause.

## Next Runtime Checks

1. rebuild and run the verifier backend with the updated Existing Business case API
2. submit policy number `12345678` from the customer page and confirm immediate proof handoff
3. complete same-device or cross-device proof sharing and verify backend status progression reaches `COMPLETED`
4. try an unsupported policy number and confirm the create request is rejected immediately
5. try a deliberate PID mismatch and verify the monitor reaches `FAILED` with explicit comparison details
6. confirm the agent monitor lists the case and auto-expands the active withdrawal while it is in progress

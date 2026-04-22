# Emerald Insurance Public Cloud Architecture

## Purpose

This note describes the public cloud proof-of-concept architecture that is currently built for the Emerald Insurance verifier demonstration.

It is intentionally architecture-focused. It does not repeat the operator steps from the wallet demo guide or the full deployment mechanics from the cloud runbook.

For authoritative operational detail, cross-reference:

- [Cloud Build And Deployment Runbook](Cloud_Build_Deployment_Runbook.md)
- [Emerald Insurance New Business Verifier Design](Emerald_Insurance_New_Business_Verifier_Design.md)
- [Emerald Insurance Existing Business Verifier Design](Emerald_Insurance_Existing_Business_Verifier_Design.md)
- [Stakeholder Wallet Demo Guide](Stakeholder_Wallet_Demo_Guide.md)

## Scope

This document covers the public `test` environment under `*.test.instech-eudi-poc.com`.

It reflects the architecture that is actually built today in the current proof of concept.

The current delivery emphasis remains verifier-first:

- primary delivery surfaces:
  - verifier web UI
  - verifier backend
- dummy or reference-backed supporting components for the current phase:
  - Android wallet
  - issuer frontend
  - issuer backend
  - authorization server

The wallet and issuer stack are current enabling components only. They are expected to be replaced by the Government sandbox in 2026.

## Architecture Summary

The public proof of concept exposes an Emerald Insurance branded verifier experience over a shared AWS `test` environment.

The verifier is split into two deployable runtime components:

- Angular verifier UI for journey selection, customer pages, and agent pages
- Kotlin verifier backend for OpenID4VP request generation, `request_uri` handling, wallet response processing, and Emerald Insurance case APIs

The issuance side remains available only to support end-to-end demonstration:

- issuer frontend for credential offer initiation
- issuer backend for issuance orchestration and metadata-driven credential behavior
- authorization server for OIDC4VCI and related token flows

The Android wallet currently acts as the mobile reference client for both issuance and presentation.

## 1. Cloud System Context

```mermaid
flowchart LR
    browser[Stakeholder Browser]
    phone[Android Wallet<br/>Dummy reference wallet<br/>Replace with Government sandbox in 2026]

    subgraph aws[AWS test environment]
        edge[Public DNS + TLS<br/>Route 53 + ACM + shared ALB]

        subgraph verifier[Verifier product surface]
            vui[Verifier UI<br/>Angular web app<br/>Primary delivery surface]
            vbe[Verifier Backend<br/>Kotlin relying-party backend<br/>Primary delivery surface]
        end

        subgraph issuer[Dummy reference issuer stack<br/>Replace with Government sandbox in 2026]
            ife[Issuer Frontend]
            ibe[Issuer Backend]
            auth[Authorization Server]
        end
    end

    browser -->|Open Emerald Insurance journeys| edge
    edge --> vui
    vui -->|Same-origin UI and case APIs| vbe

    browser -->|Open issuer page for demo issuance| edge
    edge --> ife
    ife --> ibe
    ibe --> auth

    phone -->|Fetch credential offer and issuance flows| ife
    phone -->|OIDC4VCI auth and token steps| auth
    phone -->|Resolve request_uri and submit proof| vbe
```

## 2. Cloud Deployment View

```mermaid
flowchart TB
    subgraph github[GitHub repositories and release automation]
        verifierUiRepo[eudi-web-verifier]
        verifierBackendRepo[av-srv-web-verifier-endpoint-23220-4-kt]
        issuerFrontendRepo[eudi-srv-web-issuing-frontend-eudiw-py]
        issuerBackendRepo[eudi-srv-web-issuing-eudiw-py]
        authRepo[eudi-srv-issuer-oidc-py]
        walletRepo[eudi-app-android-wallet-ui]
        actions[GitHub Actions validation publish deploy]
        releases[GitHub Releases<br/>Demo APK distribution]
    end

    subgraph aws[AWS test environment]
        ecr[ECR images]
        alb[Shared public ALB<br/>ACM TLS termination]
        dns[Route 53 public names]
        config[Parameter Store or Secrets Manager]

        subgraph ecs[ECS Fargate services]
            vui[Verifier UI service]
            vbe[Verifier backend service]
            ife[Issuer frontend service<br/>Dummy for 2026 replacement]
            ibe[Issuer backend service<br/>Dummy for 2026 replacement]
            auth[Authorization server service<br/>Dummy for 2026 replacement]
        end
    end

    verifierUiRepo --> actions
    verifierBackendRepo --> actions
    issuerFrontendRepo --> actions
    issuerBackendRepo --> actions
    authRepo --> actions
    walletRepo --> actions

    actions -->|Container publish| ecr
    actions -->|Android Demo APK publish| releases

    ecr --> ecs
    config --> ecs
    dns --> alb
    alb --> vui
    alb --> vbe
    alb --> ife
    alb --> ibe
    alb --> auth
```

## 3. Verification Flow

This is the most important cloud interaction because the verifier is the current primary delivery surface.

```mermaid
sequenceDiagram
    participant U as Stakeholder Browser
    participant VUI as Verifier UI
    participant VBE as Verifier Backend
    participant W as Android Wallet

    U->>VUI: Open Emerald Insurance customer journey
    VUI->>VBE: Create or load case
    VBE->>VBE: Build OpenID4VP request and request_uri
    VBE-->>VUI: Return case state and wallet handoff details
    VUI-->>U: Show QR code or same-device launch
    W->>VBE: Dereference request_uri and fetch request JWT
    W->>W: Select stored PID credential
    W->>VBE: Submit VP token or direct_post response
    VBE->>VBE: Validate proof and compare business fields
    VBE-->>VUI: Update case state and result
    VUI-->>U: Show verified or failed outcome
```

## 4. Issuance Flow

This flow exists only to support the current proof-of-concept end-to-end demo. It is not the primary product target.

```mermaid
sequenceDiagram
    participant U as Stakeholder Browser
    participant IFE as Issuer Frontend
    participant IBE as Issuer Backend
    participant AUTH as Authorization Server
    participant W as Android Wallet

    U->>IFE: Open issuer page
    IFE-->>U: Show credential offer link
    U->>W: Open offer on mobile
    W->>IBE: Start issuance request
    IBE->>AUTH: Delegate authorization and token steps
    AUTH-->>W: Complete OIDC4VCI authorization
    IBE-->>W: Return issued PID credential
    Note over IFE,AUTH: Dummy reference issuer path for current PoC only\nReplace with Government sandbox in 2026
```

## Key Delivery Boundaries

- The verifier UI and verifier backend are the primary delivery surfaces for the current Emerald Insurance proof of concept.
- The wallet and issuer stack are present only to enable end-to-end issuance and verification in the current sandbox.
- The wallet and issuer stack should therefore be described as dummy or reference-backed components in stakeholder material.
- The 2026 target direction is to replace those supporting components with the Government sandbox rather than evolve them as product endpoints inside this program.

## Reader Guidance

Use this note when the audience needs a concise view of the public cloud architecture and the end-to-end interaction model.

Use [Stakeholder Wallet Demo Guide](Stakeholder_Wallet_Demo_Guide.md) when the audience needs the shortest practical operator instructions for installing the wallet, issuing a PID, and running the demo journeys.

# Recorded Demos

## Purpose

This page collects the currently published proof-of-concept demo videos for the InstechSandbox EUDI insurance readiness work.

It is a viewing index, not a replacement for the architecture notes, runbooks, or journey design documents.

Some recordings reflect earlier workstream milestones, earlier branding, or earlier implementation states. They are still useful as evidence of the evolution of the proof of concept, but they should be read together with the current design and runbook documents.

For the current written source of truth, cross-reference:

- [Current PoC Scope](Current_PoC_Scope.md)
- [Emerald Insurance Public Cloud Architecture](Emerald_Insurance_Public_Cloud_Architecture.md)
- [Cloud Build And Deployment Runbook](Cloud_Build_Deployment_Runbook.md)
- [Stakeholder Wallet Demo Guide](Stakeholder_Wallet_Demo_Guide.md)

## Video Index

### Demo 0.9.3

- Video: [Demo 0.9.3](https://youtu.be/7smVqrn5W5o)
- Focus: Emerald Insurance New Business journey
- Business flow shown:
  - agent workflow covering new business setup, AML customer invite, AML checks, and AML checks passing
  - customer workflow covering AML invite receipt, credential sharing, and notification of AML success
- Why it matters: demonstrates the dual-surface verifier pattern, with an agent-facing orchestration path and a customer-facing proof-sharing path

### Demo 0.9.2

- Video: [Demo 0.9.2](https://youtu.be/SuEZfaEa9XE)
- Focus: Emerald Insurance Existing Business withdrawal journey
- Business flow shown:
  - customer workflow covering withdrawal request, POI and POA sharing, and acceptance of the withdrawal request
  - automated agent-monitor path covering customer invite generation, POI and POA receipt, automated policy-record match, and automatic withdrawal approval
- Why it matters: demonstrates a customer-driven verifier journey where the agent surface is primarily a monitoring and status workspace rather than the primary workflow driver

### Demo 0.9.1

- Video: [Demo 0.9.1](https://youtu.be/SWXTj39lZv4)
- Focus: operator guide for setting up POI and POA credentials used in proof-of-concept journey testing
- Why it matters: provides practical setup context for testers who need usable credentials before running the end-to-end verifier journeys

## Reading The Video Set

The remaining videos show two distinct aspects of the work:

- customer and agent verifier journeys for New Business and Existing Business
- test credential preparation needed to exercise those journeys reliably

If the reader wants the current implementation interpretation rather than a versioned video snapshot, start with [Current PoC Scope](Current_PoC_Scope.md) and [Cloud Build And Deployment Runbook](Cloud_Build_Deployment_Runbook.md), then use the videos as supporting evidence rather than as the primary technical specification.

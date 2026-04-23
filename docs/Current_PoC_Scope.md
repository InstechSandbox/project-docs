# Current PoC Scope

## Purpose

This note provides a brief current-state summary of what this proof of concept does, what is live now, and how to interpret the supporting components.

It is intended for customers, evaluators, and delivery teams who want a quick orientation before moving into the deeper runbooks and design notes.

## What Is Live Now

The current public proof of concept is an Emerald Insurance branded verifier demonstration running in a shared public `test` environment.

The primary delivery surfaces are:

- verifier web UI
- verifier backend

These are the main insurer-facing components in the current public demonstration.

## What Customers Can Build And Run Locally

Customers can build and run the reference implementation locally across the wallet, issuer, verifier, and supporting orchestration wrappers.

The local reference build is used to:

- exercise end-to-end issuance and verification flows
- validate interoperability across the repo set
- make integration constraints and configuration assumptions visible
- provide a repeatable engineering baseline for comparison with the public cloud path

The local build remains the fastest path for integration work and troubleshooting.

## What Runs In The Public `test` Environment

The public `test` environment exists to support an end-to-end wallet issuance and verifier proof flow over public internet endpoints.

It currently includes:

- Emerald Insurance verifier UI
- Emerald Insurance verifier backend
- issuer frontend
- issuer backend
- authorization server
- Android wallet distribution through GitHub Releases

The public cloud architecture and deployment model are described in:

- [Emerald Insurance Public Cloud Architecture](Emerald_Insurance_Public_Cloud_Architecture.md)
- [Cloud Build And Deployment Runbook](Cloud_Build_Deployment_Runbook.md)

## Primary Versus Supporting Components

In this proof of concept, the verifier is the primary insurer-facing product surface.

The wallet and issuer stack are supporting reference components that enable the current end-to-end demonstration.

They are included so the public and local demonstrators can show the full journey, but they are not the long-term product target of this program.

The current direction is that Government-led sandbox services will replace those supporting components in 2026.

## Important Interpretation Rules

- This is a proof-of-concept reference implementation, not production guidance.
- Public business branding is Emerald Insurance.
- The local and public environments are both valid reference paths, but they exist for different purposes.

## Where To Go Next

- For insurer-facing implications, read [Insurer Readiness Pack](Insurer_Readiness_Pack.md)
- For public environment shape, read [Emerald Insurance Public Cloud Architecture](Emerald_Insurance_Public_Cloud_Architecture.md)
- For local build and configuration, read [Local Build Runbook](Local_Build_Runbook.md)
- For cloud build and deployment guidance, read [Cloud Build And Deployment Runbook](Cloud_Build_Deployment_Runbook.md)
- For public demo operation, read [Stakeholder Wallet Demo Guide](Stakeholder_Wallet_Demo_Guide.md)

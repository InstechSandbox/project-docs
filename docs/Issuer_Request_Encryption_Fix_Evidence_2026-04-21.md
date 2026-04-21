# Issuer Request Encryption Fix Evidence - 2026-04-21

## Summary

- Symptom before fix: Android wallet issuance reached issuer backend `/credential` and failed with `Failed to decrypt JWE ... InvalidTag()`.
- Proven root cause: `issuer.test.instech-eudi-poc.com` served a stale `credential_request_encryption` JWK while wallets still posted `/credential` to `issuer-api.test.instech-eudi-poc.com`.
- Fix applied: issuer frontend metadata refresh now reloads upstream `credential_request_encryption` before serving `/.well-known/openid-credential-issuer`.
- Deployment path used for initial proof: one-off workspace-built issuer frontend image deployed into the shared `test` runtime.

## Runtime Evidence

- ECS service: `test-issuer-frontend`
- ECS task definition after rollout: `test-issuer-frontend:12`
- Rollout state after deploy: `COMPLETED`
- Steady-state event observed: `2026-04-21T23:31:00.388000+01:00`

## Live Metadata Evidence After Rollout

- Frontend metadata URL: `https://issuer.test.instech-eudi-poc.com/.well-known/openid-credential-issuer`
- Backend metadata URL: `https://issuer-api.test.instech-eudi-poc.com/.well-known/openid-credential-issuer`
- Frontend `credential_endpoint`: `https://issuer-api.test.instech-eudi-poc.com/credential`
- Frontend published request-encryption `kid`: `AEB34ZPueLA0a-r3FbTpjMoN9JedBEnTzT0rANZ_UGQ`
- Backend published request-encryption `kid`: `AEB34ZPueLA0a-r3FbTpjMoN9JedBEnTzT0rANZ_UGQ`
- Shared request-encryption algorithm: `ECDH-ES`

## Functional Evidence

- Operator-confirmed result after rollout: Android demo issuance succeeded.
- Operator-confirmed result after rollout: proof flow also succeeded.

## Follow-up

- Replace the one-off workspace-built frontend image with the normal repository publish and deploy path.
- Keep a post-deploy check that compares frontend and backend `credential_request_encryption` JWK values before wallet retesting.
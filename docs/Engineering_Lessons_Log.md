# Engineering Lessons Log

## Purpose

Record recurring lessons that are worth turning into shared engineering guidance.

## Entry Template

### YYYY-MM-DD - Short lesson title

### 2026-04-06 - Same-device Irish Life mismatch outcomes must be finalized server-side

- Context: After wallet Share completed with intentionally mismatched PID data, the agent view still had no terminal `FAILED` outcome unless the customer browser also returned through the Angular callback path.
- What happened: The actual field comparison logic for given name, family name, birth date, address, and expiry only ran in the customer UI after loading the wallet response with `response_code`. That meant a submitted same-device proof could exist in verifier storage while the backend case state still lacked the final mismatch evaluation.
- Reusable lesson: In same-device verifier journeys, business-critical proof matching must not depend on a frontend redirect callback. Once the wallet response is stored, the verifier backend must be able to derive and persist the terminal case outcome on its own.
- Follow-up doc or rule update: Keep Irish Life case refresh and completion flows capable of validating stored PID responses server-side so agent polling can reach `FAILED` or `COMPLETED` without a customer-page round trip.

### 2026-04-06 - Irish Life SD-JWT claim reconstruction must read JSON values, not Kotlin strings

- Context: A live Irish Life PID presentation included disclosed `given_name`, `family_name`, `birthdate`, and `date_of_expiry`, but the case summary still stored an empty `claimsSnapshot` and reported all fields as mismatched.
- What happened: The verifier reconstructed SD-JWT claims into a `JsonObject`, but the Irish Life matcher treated that payload like `Map<String, Any?>` and only accepted raw Kotlin `String` values. As a result, every disclosed JSON primitive was read as blank, producing false mismatch and expiry failures.
- Reusable lesson: When verifier-side business logic consumes reconstructed SD-JWT claims, treat the payload as structured JSON and convert `JsonPrimitive` values explicitly instead of assuming JVM-native string types.
- Follow-up doc or rule update: Keep Irish Life validation and similar verifier-side proof matching paths aligned with the SD-JWT library's `JsonObject` output so persisted `claimsSnapshot` data reflects the actual disclosed claims.

### 2026-04-06 - Irish Life PID address requests must not rely only on `address.formatted`

- Context: After fixing SD-JWT claim extraction, a fresh Irish Life proof matched name, family name, birth date, and expiry, but address still failed even though the issued PID contained structured address data.
- What happened: The Irish Life verifier requested only `address.formatted`, while the locally issued PID exposed address fields such as `street_address`, `locality`, `region`, `postal_code`, and `country` without a `formatted` value. The wallet therefore disclosed no address claim for the verifier to compare.
- Reusable lesson: For local PID interoperability, request structured address sub-fields in addition to any convenience field like `address.formatted`, then reconstruct the comparison string server-side.
- Follow-up doc or rule update: Keep Irish Life DCQL PID requests aligned with the actual local issuer payload shape and record disclosed claim paths in failed-case snapshots so missing address fields are visible without decoding presentation events manually.

### 2026-04-06 - Failed verifier journeys should render compared values, not only generic mismatch text

- Context: The Irish Life UI could already show that address validation failed, but the frontend did not reveal which application value was compared against which disclosed wallet value.
- What happened: The backend persisted a `claimsSnapshot` with the reconstructed disclosed values and claim paths, yet the UI rendered only generic lines such as `Address did not match the application.`. That left operators without enough evidence to distinguish a true mismatch from a missing disclosure.
- Reusable lesson: When the verifier persists field-level validation evidence, surface that evidence in the journey UI so failed cases can be triaged without backend log access.
- Follow-up doc or rule update: Keep Irish Life failure states rendering application-versus-wallet comparison details from the persisted validation snapshot, especially for address mismatches and missing structured claim disclosures.

### 2026-04-07 - Local proof-of-address matching should tolerate punctuation-only address differences

- Context: The local Irish Life proof-of-address flow reconstructs address from structured PID claims, but operators may type the same address into New Business with harmless punctuation or postal-code spacing differences.
- What happened: The verifier already normalized punctuation and repeated whitespace, but values such as `D02 XY56` versus `D02XY56` could still fail because internal whitespace remained significant.
- Reusable lesson: For local PID address proof matching, keep the comparison strict on underlying values but tolerant of punctuation-only and whitespace-only formatting differences inside the final address string.
- Follow-up doc or rule update: Keep Irish Life address matching aligned with the structured PID address fields and normalize compact address tokens before treating a local demo case as failed.

### 2026-04-07 - Local Irish Life address proof should not depend on `address.country`

- Context: A local issuance/proof run reported that the country code was not part of the disclosed PID proof, even though the verifier was still requesting and reconstructing address with `address.country`.
- What happened: This made the local proof-of-address path more fragile than it needed to be, because the verifier depended on one more structured field than the local demo needed to prove the core address match.
- Reusable lesson: For the local Irish Life PID demo, keep the required structured address subset minimal and stable: `street_address`, `locality`, `region`, and `postal_code`.
- Follow-up doc or rule update: Keep `address.country` optional in issuance UX, but do not require it in the Irish Life verifier request or reconstructed comparison string.

### 2026-04-07 - Irish Life demo surfaces should use Irish Life blue/white branding, not inherited verifier green

- Context: The Irish Life New Business verifier journey had been functionally tailored, but the landing, agent, and customer surfaces still used the generic verifier green/gold treatment.
- What happened: The palette looked like a default verifier theme rather than an Irish Life-specific journey, which weakened demo credibility even though the protocol flow itself was correct.
- Reusable lesson: For branded verifier demos, visual treatment is part of the journey contract. Once a flow is presented as Irish Life-specific, the UI should use Irish Life-aligned blue/white tones instead of inherited product colors.
- Follow-up doc or rule update: Keep Irish Life verifier surfaces on a consistent blue/white palette across selector, agent, and customer pages, and avoid reintroducing generic verifier green in those routes.

## Seed Entries

### 2026-04-09 - New workstream repos must be added as linked worktrees, not standalone clones

- Context: A new repository added to the `cloud-build` workspace appeared with a different VS Code icon and an unexpected nested duplicate pointing at local `main`.
- What happened: The workstream path was created as the primary clone and the canonical `main` checkout was later attached beneath it as a worktree, which inverted the layout used by the rest of the workspace.
- Reusable lesson: In the shared multi-repo workspace, the canonical checkout should stay on `main` outside the workstream directory and each `wip/<stream>` copy should be created with `git worktree add` so the on-disk git metadata shape is consistent across repositories.
- Follow-up doc or rule update: Add explicit worktree setup rules to the AI working agreement so new repositories are not inferred from branch naming alone.

### 2026-04-08 - Local Python bootstrap should prefer the cloud runtime minor version

- Context: Local issuer validation failed because one repo-local `.venv` had been created under Python 3.14 while the current container packaging path used Python 3.11.
- What happened: The backend dependency install broke locally even though the service still had a viable Docker packaging path and a working Python 3.11 runtime.
- Reusable lesson: Keep local bootstrap and cloud packaging close by preferring the current container Python minor version for local `.venv` creation, and fail fast on unsupported newer minors instead of silently accepting environment drift.
- Follow-up doc or rule update: Add a shared local Python bootstrap wrapper and require supported Python minors in the local orchestration preflight.

### 2026-04-08 - Local wrappers should absorb machine-specific SDK and trust-directory prerequisites

- Context: The post-bootstrap local build and start path still failed on one machine-specific Android SDK setting and one missing local trusted-CA directory for the issuer backend.
- What happened: The wallet Gradle build needed `sdk.dir`, and the issuer backend crashed at import time because `TRUSTED_CAS_PATH` pointed at a directory that did not exist yet.
- Reusable lesson: Put local machine prerequisites behind shared wrappers where practical so operators do not have to rediscover the same environment fixes by hand.
- Follow-up doc or rule update: Mirror Android SDK detection into wallet `local.properties` and ensure the issuer backend local trust directory exists during the local patch/start path.

### 2026-04-07 - Cloud deployment should extend the local packaging model, not fork it

- Context: The proof of concept is moving from a repeatable local build into GitHub Actions driven AWS deployment.
- What happened: The design review showed that the local wrappers were already thin enough to serve as a stable foundation, but tracked runtime JSON and SAN files were still being mutated in place for local host-specific setup.
- Reusable lesson: Preserve the local build as the engineering baseline, but converge local and cloud onto the same packaging contracts, generated runtime config, and reviewable deployment model instead of maintaining two separate systems.
- Follow-up doc or rule update: Record the single-environment `test` model, push-to-main trigger, Docker-first issuer direction, and generated-config requirement in the cloud deployment runbook and AI working agreement.

### 2026-04-03 - Local verifier client ids must match what the wallet can trust

- Context: The Irish Life verifier created a valid SD-JWT PID request on the LAN URL, but the Android wallet still failed before the consent screen and returned only a generic in-app error.
- What happened: The wallet was already configured for the local pre-registered verifier id `Verifier`, but the installed APK had been built with a stale `LOCAL_VERIFIER_API` pointing at an older LAN IP. The wallet could fetch the deep link, then still fail before consent because its pre-registered verifier metadata no longer matched the live verifier URL.
- Reusable lesson: When local verifier or issuer hosts are compiled into the wallet, a LAN IP change requires a wallet rebuild and reinstall, not just a service restart.
- Follow-up doc or rule update: Keep wallet install wrappers aligned with the current `localDemoHost`, and fail fast if the built APK still targets an older verifier URL.

### 2026-04-03 - Local issuance trust must cover every self-call path

- Context: The Irish Life SD-JWT local issuance flow had already been fixed for frontend metadata startup order, wallet trust, and auth-server attester trust, but the wallet still failed after returning from browser authorization.
- What happened: The issuer backend reached `/credential`, then failed its internal HTTPS POST to `/formatter/sd-jwt` because a shared helper ignored `SERVICE_VERIFY_TLS` and defaulted back to strict Requests verification against the local self-signed certificate.
- Reusable lesson: When a local service calls back into its own `SERVICE_URL`, every helper path must honor the repo's configured TLS verification mode rather than relying on Requests defaults.
- Follow-up doc or rule update: Keep local formatter and internal credential-generation paths aligned with `SERVICE_VERIFY_TLS`, and record the rule in the local build runbook.

### 2026-04-03 - Same-device OpenID4VP links need outer response_type for the current wallet runtime

- Context: After fixing stale wallet host configuration, the Android wallet still failed same-device SD-JWT presentation before the consent screen.
- What happened: The verifier backend emits `response_type=vp_token` on same-device links, but the Angular verifier UI also had a client-side fallback builder for `authorization_request_uri` and that path omitted `response_type`. Device-side `MissingResponseType` during UI-launched flows could therefore still be a verifier-UI deep-link assembly bug even when the signed request object at `request_uri` was correct.
- Reusable lesson: Treat every same-device deep-link builder as protocol-significant. Backend and UI fallback builders must stay aligned on `response_type`, `request_uri`, and `request_uri_method`, otherwise wallet errors can look like resolver faults while the real bug is in one remaining assembly path.
- Follow-up doc or rule update: Keep verifier backend and verifier UI deep-link builders under the same regression coverage for same-device `eudi-openid4vp://...` links.

### 2026-04-03 - Local SD-JWT issuer certs must carry the issuer HTTPS identity as a SAN URI

- Context: After same-device launch reached the wallet consent screen, SD-JWT presentation still failed immediately after Share while MSO mdoc succeeded.
- What happened: The shared local runtime cert only advertised IP and DNS SANs, and the separate SD-JWT signer certificate used in the issued credential had no SAN extensions at all. The verifier validated the SD-JWT issuer certificate against the issuer identifier `https://host:5002` and rejected the proof because the embedded leaf cert did not contain that HTTPS service identity as a SAN URI.
- Reusable lesson: For local SD-JWT issuer validation, trust is not just about the CA chain or the live TLS cert. The signer certificate embedded in the SD-JWT must also advertise the issuer HTTPS identity in SAN URI form, and any wallet APK that embeds the old PEM must be rebuilt after the runtime cert rotates.
- Follow-up doc or rule update: Generate SAN URI entries for the local auth, issuer, frontend, and verifier HTTPS URLs, regenerate the local Utopia SD-JWT signer PEM and DER from the existing private key when the issuer URL changes, and make the wallet build/install wrappers fail fast on PEM drift.

### 2026-04-04 - Local Irish Life SD-JWT proofs need an explicit PID issuer chain

- Context: The Irish Life case API created same-device PID proof requests without using the verifier UI's manual trusted-issuer control, and proof sharing still failed after the local signer cert itself had been fixed.
- What happened: The verifier only had default trust-source rules for age-verification documents, so SD-JWT PID validation in the Irish Life flow still had no trusted issuer chain unless one was passed in the transaction init request. The wallet could fetch the request object and reach Share, then direct-post failed with `IssuerCertificateIsNotTrusted` because the transaction carried no PID `issuer_chain`.
- Reusable lesson: When a local verifier journey bypasses the manual trusted-issuer UI, the flow itself must supply the issuer chain or an equivalent verifier-side trust source for the requested VCT.
- Follow-up doc or rule update: Mount the local PID signer cert into the verifier runtime and inject it into Irish Life transaction init requests so same-device SD-JWT proofs use the same trust anchor path as the local issuer.

### 2026-04-05 - Agent spinners need browser-side guardrails even after backend fixes

- Context: The Irish Life `Create case and send invite` action had already been fixed server-side for placeholder SMTP hangs, but the agent page could still be left showing a spinner with no visible progress when the browser-side request chain stalled.
- What happened: The deployed Angular build was current and same-origin, so the remaining failure mode was a frontend wait state that gave the operator no clue whether case creation or invite dispatch was still outstanding. That made retry behavior unsafe because the backend might already have completed one of the two steps.
- Reusable lesson: For multi-step local orchestration flows, do not rely on a single generic busy flag. Show the active step and add a browser-side timeout that tells the operator to refresh current state before retrying.
- Follow-up doc or rule update: Keep the Irish Life agent UI aligned with backend state by labeling the active step and treating a long browser wait as a recoverable UI condition rather than an infinite spinner.

### 2026-04-05 - Terminal proof outcomes must render from persisted case state

- Context: The Irish Life customer proof page could complete or fail a proof evaluation, but a later reload or re-entry could lose the in-memory transaction object that originally drove the success or failure banner.
- What happened: The customer page only rendered the terminal result banner when it still held a live `concludedTransaction`, even though the backend already persisted `FAILED`, `failureReason`, and field-match validation details on the case summary. That made mismatched proofs easy to miss because the screen could reopen without a clear terminal outcome.
- Reusable lesson: For verifier journeys, user-facing terminal states must be derived from persisted backend case state, not only transient browser callback state.
- Follow-up doc or rule update: Keep Irish Life customer pages rendering `COMPLETED` and `FAILED` outcomes directly from case summary data, including persisted mismatch reasons.

### 2026-04-06 - Agent status polling must tolerate transient refresh failures

- Context: In the Irish Life New Business flow, an agent can create a case and leave the page open while the customer completes or fails proof sharing elsewhere.
- What happened: The agent page relied on a simple polling subscription with no error handling. Any single failed `getCase` request could terminate polling silently, leaving the UI stuck on the last seen state such as `INVITE_SENT` even though the backend case had already moved to `FAILED` or `COMPLETED`.
- Reusable lesson: Long-running verifier status polling must treat refresh failures as recoverable and continue polling unless the case reaches a terminal state.
- Follow-up doc or rule update: Keep the Irish Life agent UI surfacing transient refresh errors while allowing polling to continue until a terminal case status is observed.

### 2026-04-06 - Same-device case polling must not depend on response_code once the wallet response is stored

- Context: In the Irish Life unhappy path, the customer completed Share on the wallet, but the support-agent page stayed at `INVITE_SENT`.
- What happened: The agent page polls case status through backend `GET /cases/{caseId}` calls, which in turn refresh the case from the stored wallet response using `getWalletResponse(transactionId, null)`. The verifier runtime treated a submitted same-device presentation as unavailable unless the original `response_code` was provided, so the case refresh never saw the stored wallet response and the agent page remained stuck before `PROOFS_RECEIVED`.
- Reusable lesson: Once a wallet response has already been persisted for a submitted presentation, backend case refresh logic must be able to observe it without requiring the same-device redirect `response_code` again.
- Follow-up doc or rule update: Keep Irish Life support-agent polling and any similar backend case refresh path compatible with submitted same-device presentations after the original customer redirect has finished.

### 2026-03-31 - Local runtime artifacts must remain untracked

- Context: Local EUDI orchestration relies on certificates, JWKS files, and generated runtime assets that differ per machine.
- What happened: Several repositories required explicit ignore discipline and repeatable wrapper scripts to keep local artifacts out of source control.
- Reusable lesson: Encode local-only artifact rules in git hooks and docs rather than relying on memory.
- Follow-up doc or rule update: Keep local-only artifact checks in shared git hooks and repo guidance.

### 2026-03-31 - Forward references in local env files can break runtime assumptions

- Context: A derived `.env` value referenced another variable defined later in the file.
- What happened: `DEFAULT_FRONTEND=${FRONTEND_ID}` resolved incorrectly and broke the credential offer flow.
- Reusable lesson: Do not rely on forward references in local environment files when runtime behaviour depends on the resolved value.
- Follow-up doc or rule update: Prefer explicit values or validated generation scripts for critical local env fields.

### 2026-04-01 - New shared gates can expose pre-existing repo health debt

- Context: Shared pre-push hooks were introduced across the multi-repo workspace to enforce repo-native deterministic checks.
- What happened: Foundation-only commits that changed only `.github/copilot-instructions.md` were blocked in several repos by pre-existing Gradle, pytest, and ESLint failures unrelated to the changed files.
- Reusable lesson: When a change only introduces governance or documentation files outside the product runtime path, failing quality gates should be treated first as potentially pre-existing repository debt rather than as regressions caused by that change.
- Follow-up doc or rule update: If delivery needs require a temporary bypass, record a dedicated shared-hook bypass commit, track the affected repos in the gate debt backlog, and revert that specific commit once the repo-native gates are fixed.

### 2026-04-02 - Credential abbreviations can hide domain meaning

- Context: The Irish Life New Business design needed a proof-of-address credential and the issuer metadata exposed a `por` credential identifier.
- What happened: `por` initially looked like a possible Proof of Residence or Proof of Address candidate, but metadata inspection showed it actually meant Power Of Representation.
- Reusable lesson: Do not infer business meaning from credential ids or abbreviations alone; verify the actual metadata claims and display name before using a credential in a standards-sensitive journey.
- Follow-up doc or rule update: Keep credential selection decisions tied to inspected metadata and record naming pitfalls in design notes when they can mislead future work.

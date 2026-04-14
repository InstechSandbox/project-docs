# Engineering Lessons Log

## Purpose

Record recurring lessons that are worth turning into shared engineering guidance.

### 2026-04-10 - Scripted same-device verifier deep links are better triage than repeated Safari retries on iOS simulator

- Context: A local same-device verifier deeplink on iOS could switch from Safari into the wallet app, yet still fail to start the actual proof request.
- What happened: That handoff proved the URL scheme registration existed, but it did not prove that the generated OpenID4VP deep link itself was complete. The CLI verifier deep-link generator could also rebuild links without `response_type=vp_token`, which makes the wallet open and then stop before proof handling starts.
- Reusable lesson: When iOS same-device verification appears to stall after app switch, test first with a scripted deep link that opens directly in the simulator. That isolates wallet-side deep-link parsing from Safari or verifier-UI handoff issues and catches missing required parameters earlier.
- Follow-up doc or rule update: Keep the verifier deep-link generator preserving `authorization_request_uri` when available, and keep a shared `run-ios-verification-deeplink.sh` wrapper for simulator triage.

### 2026-04-13 - Local verifier deep-link generators must preserve the trusted TLS port

- Context: A same-device iOS simulator proof switched from the previous verifier-auth failure into `Invalid DCQL query`, but the visible wallet message was now a server-certificate warning for `192.168.0.131`.
- What happened: The direct verifier deep-link generator defaulted `VERIFIER_PUBLIC_URL` to `https://<lan-ip>` without the local verifier TLS port, even though the shared local stack, simulator trust, and verifier wrappers were aligned to `https://<lan-ip>:4443`. The wallet then fetched a request URI from the wrong TLS endpoint and surfaced the certificate mismatch as another misleading DCQL error.
- Reusable lesson: For the shared local verifier stack, every deep-link generator must derive its default public URL from `VERIFIER_TLS_HOST_PORT` rather than assuming bare `443`. Otherwise direct script usage can silently bypass the trusted local verifier endpoint even while the wrapper scripts stay correct.
- Follow-up doc or rule update: Keep direct verifier deep-link scripts using the same `VERIFIER_TLS_HOST_PORT` and `VERIFIER_PUBLIC_URL` defaulting logic as the local verifier startup wrappers.

### 2026-04-13 - ExtensionKit proof flows must not derive keychain service names from the extension bundle id

- Context: The iOS simulator proof flow continued to report `Invalid pin` after the entered value was confirmed and the quick-PIN compare path was instrumented.
- What happened: Simulator-only debug logs showed the proof authorization flow receiving the entered six-digit PIN while the stored PIN lookup returned `nil`. The failing screen was hosted by `EudiReferenceWalletIDProvider`, and the shared bundle helper only recognized classic `.appex` paths as extensions. In the ExtensionKit-hosted proof flow that can leave the extension deriving its own bundle id instead of the main app bundle id, which points keychain-backed PIN lookup at an empty namespace.
- Reusable lesson: For iOS ExtensionKit integrations, bundle-id normalization must detect extension contexts from plist extension attributes as well as `.appex` paths. Otherwise auth and document service names can diverge between the main app and provider-hosted proof flows even though both are in the same local wallet build.
- Follow-up doc or rule update: Keep `Bundle.getMainAppBundleID()` treating `EXAppExtensionAttributes` and related extension markers as authoritative extension signals when deriving shared keychain and storage service names.

### 2026-04-13 - Unsigned iOS simulator builds cannot rely on keychain-backed quick PIN storage

- Context: The iOS simulator wallet repeatedly reported `Invalid pin` during same-device proof even after the entered digits and bundle/service namespace had been confirmed.
- What happened: Explicit keychain error logging showed the unsigned simulator build had neither `application-identifier` nor `keychain-access-groups` entitlements, so both quick-PIN reads and writes were failing inside the local simulator workflow. Earlier subscript-based keychain APIs masked that failure and made it look like the PIN had been stored and then lost.
- Reusable lesson: For the shared unsigned iOS simulator path, do not depend on keychain-backed quick-PIN storage. Use a simulator-only non-keychain persistence backend for local proof triage, and reserve keychain-backed PIN storage for signed builds that actually carry the required entitlements.
- Follow-up doc or rule update: Keep simulator quick-PIN storage separate from the signed-device keychain path, and use explicit throwing keychain APIs when debugging entitlement-sensitive storage failures.

### 2026-04-10 - iOS local simulator wrappers should fail before a build ships without the local issuer override

- Context: The simulator wallet could build, install, and launch, but the issuance screen showed no local credential types because the app had only the local verifier override compiled in.
- What happened: The shared iOS wrapper defaulted the local verifier URL but still treated the local issuer and attestation URLs as opt-in. That produced a misleading half-local simulator build that passed launch smoke but could never exercise the local issuance path.
- Reusable lesson: For the shared local iOS simulator path, default the whole local stack together and assert the compiled bundle values during smoke. Missing local issuer metadata is not just a runtime nuisance; it is a build-time misconfiguration that should fail fast.
- Follow-up doc or rule update: Keep `IOS_USE_LOCAL_STACK` enabled by default in the shared wrappers and keep `smoke-ios-wallet-simulator.sh` validating the compiled local issuer, attestation, and verifier plist values before launch.

### 2026-04-10 - Local iOS same-device verifier flows need preregistered verifier metadata compiled into the wallet

- Context: A local same-device verifier deeplink on the iOS simulator opened the wallet app, but the verifier backend never saw a follow-up `/wallet/request.jwt/...` fetch.
- What happened: The local verifier backend still advertised the default preregistered `client_id=Verifier`, while the iOS wallet build only enabled `x509_san_dns` and `x509_hash` OpenID4VP client id schemes. That let the custom-scheme deeplink reach the app, then fail inside wallet-side request validation before `request_uri` dereferencing even started.
- Reusable lesson: When a local verifier relies on a preregistered OpenID4VP client id, the iOS wallet must be built with matching preregistered verifier metadata for that local verifier URL and client id. Otherwise a deeplink can appear to work while the flow dies before any network activity.
- Follow-up doc or rule update: Keep the local iOS simulator build wrappers forwarding `IOS_LOCAL_VERIFIER_URL` and `IOS_LOCAL_VERIFIER_CLIENT_ID` into the wallet's plist-backed VP configuration so same-device verifier runs stay aligned with the local verifier backend defaults.

### 2026-04-10 - Local iOS verifier proof currently requires single-credential PID issuance

- Context: A scripted local OpenID4VP deeplink on iOS reached the wallet, but the app crashed immediately before showing the proof request.
- What happened: The crash report showed `Dictionary.init(uniqueKeysWithValues:)` failing inside `EudiWallet.prepareServiceDataParameters(format:)` while building presentation data from issued documents. The current wallet-kit issuance path stores every credential in a one-time-use PID batch under the same document id, so presentation crashes as soon as more than one credential from that batch is present.
- Reusable lesson: For local iOS verifier testing, a real device does not avoid wallet-side duplicate document-id crashes. If the wallet still issues one-time-use PID batches with shared ids, keep local PID issuance to a single credential until the upstream wallet-kit batch-save path assigns unique document ids.
- Follow-up doc or rule update: Keep the iOS local verifier path on `numberOfCredentials = 1` for PID issuance until the upstream wallet-kit batch issuance bug is fixed.

### 2026-04-12 - Simulator issued-document loading must collapse batch entries to primary document ids

- Context: Same-device verifier deeplinks on the iOS simulator still crashed even after the extra JWT PID credential had been deleted from the wallet UI.
- What happened: The simulator-only storage service returned both the primary issued record and its per-credential batch entries from `loadDocuments(status: .issued)`. Wallet-kit then built `Dictionary(uniqueKeysWithValues:)` maps keyed by document id during OpenID4VP setup and trapped as soon as more than one stored record shared that id.
- Reusable lesson: For simulator-backed wallet storage, issued-document enumeration must expose one logical document per document id. Batch credential records can remain addressable for key selection, but they must not be surfaced as separate issued documents during presentation setup.
- Follow-up doc or rule update: Keep `SimulatorDataStorageService.loadDocuments(status:)` deduplicating by document id and preferring the primary issued record over batch-key entries so local same-device verifier triage is not blocked by simulator storage shape.

### 2026-04-10 - Local mdoc signer refresh must preserve the DS-under-IACA chain

- Context: iOS issuance moved past the OpenID4VCI request-encryption failure and then failed during mdoc MSO validation with `the signed date is not within the validity period of the cert in the MSO`.
- What happened: The local issuer preferred the `PID-DS-LOCAL-UT` filenames, but `scripts/refresh-local-certs.sh` still validated that signer cert like a host-bound TLS leaf and regenerated it as a self-signed `Local Utopia DS` certificate. Android tolerated that local shortcut, while iOS rejected the resulting MSO signer certificate.
- Reusable lesson: When local mdoc signer material uses the preferred `PID-DS-LOCAL-UT` filenames, shared refresh scripts must validate that DS certificate against the active key and local IACA chain instead of host-style SAN rules.
- Follow-up doc or rule update: Keep local signer refresh paths regenerating the full IACA plus DS chain via `scripts/generate-local-mdoc-signer-chain.sh` rather than minting a self-signed DS leaf.

### 2026-04-13 - Local SD-JWT signer chains still need the issuer URL in the leaf certificate SAN

- Context: Same-device iOS proof moved past the simulator PIN issue and still failed verifier validation with `Failed to find https://192.168.0.131:15002 in SAN URI or SAN DNS entries of provided leaf certificate`.
- What happened: The shared local DS-under-IACA generator fixed the mdoc certificate profile, but the regenerated `PID-DS-LOCAL-UT` leaf no longer carried `URI:$ISSUER_URL` in `subjectAltName`. The verifier uses that SD-JWT issuer certificate SAN to bind the presented credential to the local issuer HTTPS identity, so proof kept failing even after reissuing the JWT PID.
- Reusable lesson: The local DS leaf serves two jobs at once in this stack: mdoc signer profiling and SD-JWT issuer binding. Regenerating the DS-under-IACA chain must preserve the issuer HTTPS identity in the leaf SAN, not just the chain shape.
- Follow-up doc or rule update: Keep `scripts/generate-local-mdoc-signer-chain.sh` and `scripts/refresh-local-certs.sh` enforcing `URI:$ISSUER_URL` plus the local host entries on `PID-DS-LOCAL-UT_cert.pem`.

### 2026-04-10 - Local mdoc signer certs must start slightly before current issuance time

- Context: After restoring the DS-under-IACA chain, iOS still rejected a newly issued mdoc because the MSO `signed` timestamp landed just before the signer certificate `notBefore` second.
- What happened: The local signer generator minted certificates with a `notBefore` equal to generation time down to the second, while the issued MSO timestamp could be normalized slightly earlier by the formatting stack. That made a same-minute cert and MSO look valid to an operator but still fail strict certificate-window checks.
- Reusable lesson: For local interoperability signer chains, backdate generated certificate validity slightly so the MSO `signed` timestamp cannot fall a few seconds before the signer certificate becomes valid.
- Follow-up doc or rule update: Keep `scripts/generate-local-mdoc-signer-chain.sh` generating local IACA and DS certificates with a small negative validity offset instead of starting exactly at creation time.

## Entry Template

### YYYY-MM-DD - Short lesson title

### 2026-04-13 - Customer-driven verifier journeys must compare wallet proof against server-owned records, not operator-entered values

- Context: The first Existing Business implementation let the agent create the withdrawal case and type the identity and address values later used for PID comparison.
- What happened: That produced a coherent demo technically, but it inverted the intended ownership model and weakened the credibility of the automated checks because the verifier was matching against agent-entered data instead of an internal Irish Life policy record.
- Reusable lesson: If a journey is described as customer-driven and automated, the verifier must own the comparison baseline server-side and treat the agent surface as a monitor unless manual intervention is explicitly part of the design.
- Follow-up doc or rule update: Keep policy, account, and comparison-record lookup in the backend for Existing Business-style journeys, and avoid building operator forms that become the de facto source of truth.

### 2026-04-10 - Customer entry surfaces must not imply business-reference lookup unless the backend supports it

- Context: The Irish Life customer-entry pages invited users to enter a case or claim reference, but the implemented routes actually load journeys by internal verifier case ID only.
- What happened: The wording drifted ahead of the real backend capability, which risked sending operators or customers down a path that could never resolve successfully without an additional lookup endpoint.
- Reusable lesson: Entry-page language is part of the contract. If a verifier flow is keyed by internal case ID, the UI must say so explicitly until a real business-identifier lookup exists.
- Follow-up doc or rule update: Keep Irish Life entry forms aligned with the actual backend lookup capability, and do not use policy reference or claim reference wording on direct-entry pages unless those identifiers are truly resolvable.

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
- Reusable lesson: When a local verifier journey bypasses the manual trusted-issuer UI, the flow itself must supply the issuer chain or an equivalent verifier-side trust source for the requested VCT. In the Irish Life PID flow that `issuer_chain` is parsed as PKIX trust anchors, so the correct local input is the issuer CA PEM, not the DS leaf PEM embedded into the SD-JWT.
- Follow-up doc or rule update: Mount the local PID issuer CA PEM into the verifier runtime and inject it into Irish Life transaction init requests. Keep the DS PEM only as a compatibility fallback, and restart the verifier whenever the local IACA or DS signer material changes.

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

### 2026-04-09 - Local mdoc signer chains should target the strictest wallet validator

- Context: The Irish Life local issuer stack was exercised against both Android and iPhone wallets for PID mdoc issuance while using local LAN services and self-signed transport TLS.
- What happened: Android accepted the locally signed mdoc flow, but iPhone rejected the MSO `x5chain` because the configured local signer certificate was self-issued instead of behaving like an end-entity document signer certificate under an IACA.
- Reusable lesson: Do not treat a more permissive wallet as proof that local mdoc signer material is correctly profiled. For cross-platform local demos, keep self-signed HTTPS as a transport-only convenience, but shape mdoc signer certificates to the stricter DS-under-IACA model that production trust chains are expected to follow.
- Follow-up doc or rule update: Use local demo signer material that mirrors the production trust shape for mdoc issuance, and treat platform-specific acceptance of weaker local chains as a compatibility trap rather than a target design.

### 2026-04-09 - Bundled demo DS certificates can expire before the local runbook does

- Context: The local issuance stack was rebuilt with generated runtime metadata overrides for OpenID4VCI credential-request encryption, but one runtime file still embedded an older nested request-encryption key while the backend decrypted with the current private key.
- What happened: The issuer backend code could repair that mismatch in memory when started with the correct overrides, but any stale process or consumer reading the generated override file directly still saw an inconsistent key set. That surfaced on iOS as `OpenID4vci.credentialissuanceerror error 5` after authorization completed, because the wallet encrypted the credential request JWE to a different public key than the backend private key expected.
- Reusable lesson: Generated OpenID4VCI metadata overrides must be internally self-consistent. Do not rely on a later in-memory merge step to reconcile a stale nested `credential_request_encryption.jwks` block with a newer top-level override key.
- Follow-up doc or rule update: Keep the issuer local patch generator replacing the nested `credential_request_encryption.jwks` entry with the active public JWK derived from `credential_request_ec.pem`, then verify the live `/.well-known/openid-credential-issuer` response after restart.

- Context: The issuer repo ships sample Utopia DS bundles under `api_docs/test_tokens/DS-token/`, and they looked like the simplest way to move from a self-issued signer to a DS-under-IACA model.
- What happened: All tracked sample DS leaves were already expired in April 2026, so switching to the bundled examples fixed the certificate profile shape but still failed OpenSSL validation on certificate freshness.
- Reusable lesson: Treat repo-shipped demo signer bundles as short-lived examples, not durable local runtime dependencies. Local mdoc flows need a refreshable signer-generation path, not a hidden assumption that example DS material will still be valid months later.
- Follow-up doc or rule update: Keep a local signer-generation script in the shared runbook path and prefer optional local trust-root loading in the wallets over committing machine-specific demo trust artifacts.

### 2026-04-07 - Short-lived workstreams need an explicit comparison-base rule

- Context: Multiple isolated workspaces were created for Irish Life verifier, iOS wallet, and cloud build work using local `wip/<stream>` branches.
- What happened: The intended trunk-friendly model was applied intentionally in some workspaces, but the branch comparison rule was not documented clearly enough, which made the workspaces look inconsistent even though they followed the same delivery style.
- Reusable lesson: If unpublished short-lived workstream branches are intended to compare against `origin/main`, document that explicitly so branch metadata is treated as part of the workflow contract rather than as accidental local state.
- Follow-up doc or rule update: Record the short-lived `wip/<stream>` cadence and the optional `origin/main` comparison-base rule in the AI working agreement and cloud-build runbook.

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

### 2026-04-05 - Command Line Tools are not enough for iOS build reconnaissance

- Context: The new `ios-wallet` workstream started validating the local build path for `eudi-app-ios-wallet-ui`.
- What happened: `xcodebuild` failed immediately because `xcode-select` pointed at `/Library/Developer/CommandLineTools`, and no full Xcode app was installed in the normal application locations.
- Reusable lesson: Treat full Xcode installation and `xcode-select` validation as the first gate in any repeatable iOS build runbook; Command Line Tools alone are insufficient.
- Follow-up doc or rule update: Keep iOS runbooks explicit about checking both Xcode presence and the active developer directory before attempting simulator or device builds.

### 2026-04-07 - iOS local issuer overrides must follow the published credential_issuer, not every local port

- Context: The iOS wallet was being connected to the local issuer and auth stack while preserving the upstream hosted Dev and Demo defaults.
- What happened: The iOS issuer map keys services by URL host only, so a naive local mirror of both `5002` and `5003` would collide even though the stack uses separate ports.
- Reusable lesson: When a client indexes issuer services by host rather than host plus port, local overrides must target the canonical published `credential_issuer` URL and treat auxiliary local services like attestation separately.
- Follow-up doc or rule update: Keep the iOS local runbook explicit that the wallet uses the frontend issuer URL on `5003`, the auth server attestation URL on `5001`, and host-scoped self-signed TLS overrides only for configured local hosts.

### 2026-04-08 - iOS simulator trust must match the live local stack cert, not just the current workspace cert

- Context: The iOS wallet simulator smoke path imported the shared local cert from this worktree before browser-based issuance handoff.
- What happened: Another sibling worktree was already running auth and issuer services on the same local ports with a different certificate, so the simulator trusted one cert while Safari connected to another and kept showing the private-connection warning.
- Reusable lesson: In a multi-worktree local environment, always compare the live endpoint certificate fingerprint against the worktree's expected shared cert before treating simulator root-cert import as sufficient.
- Follow-up doc or rule update: Keep the shared smoke scripts checking live TLS certificate alignment for auth and issuer endpoints, and fail fast when another local stack is bound to the same ports.

### 2026-04-08 - iOS simulator issuance cannot rely on access-group keychain entitlements

- Context: The local iOS issuance path was exercised on an iOS 26 simulator build after browser trust had been fixed.
- What happened: Credential issuance hit KeychainAccess error `-34018` with the message that a required entitlement was not present, because the simulator app did not have effective `application-identifier` and `keychain-access-groups` entitlements for the configured access-group keychain path.
- Reusable lesson: Keep simulator-only issuance paths off shared access-group keychain configuration unless the simulator build is signed in a way that actually provides those entitlements.
- Follow-up doc or rule update: Simulator builds now fall back to the default app keychain without an access group, while device builds keep the access-group path for the signed app and extension setup.

### 2026-04-08 - iOS simulator issuance cannot assume Identity Document Services entitlements either

- Context: After removing the shared keychain access-group path from the simulator issuance flow, the same entitlement error still appeared when the wallet fetched freshly issued CBOR documents on an iOS 26 simulator.
- What happened: The wallet still called `IdentityDocumentProviderRegistrationStore` through `DocumentRegistrationManagerImpl` during post-issuance document registration, and that simulator path also depends on entitlements that are not effectively present in the unsigned local simulator workflow.
- Reusable lesson: For local iOS simulator validation, treat Identity Document Services registration like other entitlement-gated runtime features and use a no-op fallback unless the simulator build is signed with effective capabilities.
- Follow-up doc or rule update: Simulator builds now resolve `DocumentRegistrationManagerNoOp`; only non-simulator iOS 26+ builds use the real Identity Document Services registration manager.

### 2026-04-08 - Unsigned iOS 26 simulators may not support wallet keychain persistence at all

- Context: Even after removing the shared access-group path and the Identity Document Services registration path, local issuance on the simulator still failed with the same entitlement message.
- What happened: Fresh simulator logs showed raw `SecItemAdd` failures with `-34018` from the main `EudiWallet` process, which traced back to wallet-kit's default `KeyChainStorageService` and `KeyChainSecureKeyStorage` persistence path.
- Reusable lesson: On unsigned simulator builds, treat wallet persistence itself as potentially non-viable on the keychain path; if the goal is local flow validation, inject a simulator-only in-memory storage backend rather than assuming `nil` access-group alone is sufficient.
- Follow-up doc or rule update: Simulator builds now inject in-memory document storage and in-memory secure-key storage into wallet-kit, while device builds keep the normal persistent keychain-backed storage.

### 2026-04-08 - Local wallet PID issuance batches must stay aligned with the issuer-authored credential policy

- Context: After the simulator entitlement blockers were removed, local PID issuance reached the credential step but still failed after authorization and token exchange.
- What happened: The iOS wallet `DEV` build requested 60 one-time PID credentials, while the local issuer's PID credential metadata was authored with a policy batch size of 15 even though the top-level issuer metadata allowed larger global batches.
- Reusable lesson: Treat credential-specific issuance policy as the safer local compatibility target; avoid oversized wallet-side batch overrides unless the live issuer flow has been verified end-to-end for that credential.
- Follow-up doc or rule update: The iOS wallet local `DEV` PID issuance batch is aligned back to 15 so local issuance matches the issuer-authored PID policy.

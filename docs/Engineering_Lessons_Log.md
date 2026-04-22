# Engineering Lessons Log

## Purpose

Record recurring lessons that are worth turning into shared engineering guidance.

### 2026-04-22 - Fork-owned CI noise should fail closed only for real findings, not missing optional service tokens or deprecated artifact helpers

- Context: The `InstechSandbox` fork repos were producing failure emails after routine workflow-pin pushes even though the runtime deploy path, JWK alignment check, and end-to-end issuance and proof flow were all working.
- What happened: The fork-owned SonarCloud workflows treated a missing `SONAR_TOKEN` as a hard failure in an initial secret-check job, and the fork-owned issuer-frontend Gitleaks workflow still depended on deprecated `actions/upload-artifact@v3`, which GitHub now auto-fails during job setup. Those failures created misleading incident noise without proving a runtime regression or a real secret-scanning finding.
- Reusable lesson: In fork-owned delivery repos, optional third-party analysis should skip cleanly when the required service credential is intentionally absent, and inherited artifact actions must be kept on supported major versions. Otherwise workflow noise can look like product instability even when the deployed system is healthy.
- Follow-up doc or rule update: Keep SonarCloud workflows emitting a skip signal instead of failing when `SONAR_TOKEN` is absent, and keep Gitleaks artifact upload steps on `actions/upload-artifact@v4` with `if-no-files-found: warn` so only actual scan findings or runner failures page the team.

### 2026-04-21 - Demo and Dev Android wallets must not share the same OpenID4VCI authorization callback URI

- Context: Cloud PID issuance retries remained ambiguous even after backend fixes because both installed Android wallet flavors could claim the same browser-return URI `eu.europa.ec.euidi://authorization`.
- What happened: The `demo` flavor is the intended cloud app and the `dev` flavor is the local app, but both exported the same OpenID4VCI authorization callback scheme and host. On a test device with both apps installed, Android resolved that callback to `eu.europa.ec.euidi.dev`, so the OS could deliver the cloud authorization return to the wrong wallet flavor before issuance resumed.
- Reusable lesson: Flavor-specific package ids are not enough when the authorization callback URI is shared. If demo and dev need to coexist on one device, each flavor must advertise a distinct OpenID4VCI authorization callback scheme so Android intent resolution cannot silently steal the browser return.
- Follow-up doc or rule update: Keep the Android demo flavor on `eu.europa.ec.euidi://authorization` for cloud testing, and keep the dev flavor on its own callback scheme so both APKs can stay installed without cross-flavor redirect collisions.
- Implementation note: The shared Android flavor wiring and merged manifests now enforce that split, so future callback debugging should treat any cross-flavor browser return as a regression.

### 2026-04-21 - Issuer request-encryption metadata and decrypt key must stay pinned to the same runtime key

- Context: Android wallet issuance started failing after browser authorization with issuer backend logs showing `POST /credential 400` and `Failed to decrypt JWE ... InvalidTag()` even though the wallet JWE header matched the live `credential_request_encryption` metadata `kid` and algorithm.
- What happened: The issuer bootstrap path generated and published the credential-request public JWK once at startup, but the `/credential` handler still reopened `CREDENTIAL_KEY` from the writable runtime directory on each request. That made the advertised key and the decrypt key separable if the runtime file drifted, which is exactly the failure shape for an `ECDH-ES` decrypt mismatch.
- Reusable lesson: For protocol-facing request encryption, treat the published JWK and the server private key as one startup-time contract. Load the private key once, validate it against the published metadata before serving traffic, and do not rely on rereading a writable runtime key file per request.
- Follow-up doc or rule update: Keep issuer startup validating `credential_request_encryption` against `CREDENTIAL_KEY`, and keep the request decrypt path using the startup-loaded key rather than rereading `/tmp` runtime files on every credential request.

### 2026-04-21 - Frontend-hosted issuer metadata must refresh backend request-encryption keys after backend redeploys

- Context: Public test Android issuance still failed with `Failed to decrypt JWE ... InvalidTag()` after the issuer backend was fixed to pin its decrypt key at startup.
- What happened: The demo wallet defaulted to `https://issuer.test.instech-eudi-poc.com` for issuer metadata, and that frontend-hosted metadata pointed `credential_endpoint` at `https://issuer-api.test.instech-eudi-poc.com/credential`. Live checks showed the frontend was serving `credential_request_encryption` key `kid=QgVaK7trQ1MbRnhZd8PoMK5mauGGWvWD8xxrB9pM7uI` while the backend host published and used `kid=AEB34ZPueLA0a-r3FbTpjMoN9JedBEnTzT0rANZ_UGQ`. The wallet therefore encrypted the JWE to the frontend key and posted it to a backend task holding a different private key, which deterministically produced the `InvalidTag` decrypt failure.
- Reusable lesson: In a split frontend or backend issuer topology, `issuer.<base-domain>` metadata is protocol-critical state, not a cosmetic mirror. If the frontend caches backend request-encryption metadata only at startup, any backend task rotation that changes the request-encryption key can break issuance until the frontend is also restarted or refreshed.
- Follow-up doc or rule update: Keep the issuer frontend refreshing upstream `credential_request_encryption` before serving `/.well-known/openid-credential-issuer`, and include a post-deploy check that `issuer.<base-domain>` and `issuer-api.<base-domain>` publish the same request-encryption JWK before retesting wallets.

### 2026-04-22 - Issuer key-alignment guardrail failures are real rollout-risk signals, not noise

- Context: A later `Publish` failure in `InstechSandbox/eudi-web-verifier` happened after the stale-frontend fix was already live, and the failing step was the shared `Verify issuer request-encryption key alignment` guardrail.
- What happened: The issuer backend runtime still allows the request-encryption EC key to be generated ephemerally at container startup. That means a backend rollout can legitimately publish a new `credential_request_encryption` JWK before the issuer frontend is serving the same key. At `2026-04-22T00:44Z`, the guardrail observed exactly that mismatch between `issuer.test...` and `issuer-api.test...`, so a client testing issuance during that window could have failed even though the environment aligned again later.
- Reusable lesson: After the stale-frontend fix, issuer key drift is more likely to be a rollout-window consistency problem than a persistent stuck-cache bug, but the risk is still real while the frontend and backend publish different request-encryption keys. Treat the failure email as evidence that the environment should not be assumed issuance-safe until live metadata alignment is rechecked.
- Operational note: This does not reliably self-heal within a few minutes on its own. Recovery is to verify live frontend and backend `/.well-known/openid-credential-issuer` responses, then rerun or force the issuer frontend rollout if the backend has rotated to a new key and the frontend still advertises the old one.
- Follow-up doc or rule update: For the current POC, keep the alignment guardrail and the live metadata check as the operational recovery path. If this recurs outside planned rollouts or affects client demos repeatedly, promote persistent request-encryption key material or stricter issuer deployment sequencing from future improvement to active work.

### 2026-04-21 - Private ECS DNS needs both the correct Terraform state key and runtime security-group self-ingress

- Context: The public `test` verifier UI was changed to proxy Emerald Insurance case traffic to the verifier backend over private ECS DNS instead of hairpinning through the public verifier API host.
- What happened: Two manual redeploy attempts failed before rollout because they were pointed at `iac/environments/test/runtime.tfstate`, which contained only a partial duplicate scaffold, while the live runtime was actually tracked in `iac/environments/test-runtime/terraform.tfstate`. After the deploy was rerun against the correct state key, the verifier UI resolved `test-verifier-backend.test.runtime.internal` correctly but still timed out because the shared runtime security group only allowed ingress from the public ALB and not from peer tasks in the same security group.
- Reusable lesson: When adding private service-to-service traffic inside this ECS runtime, verify two contracts together: the deploy workflow must target the actual runtime state key for the `test-runtime` root, and the shared runtime security group must explicitly allow same-group ingress on the container ports. Fixing only DNS target selection is not enough.
- Follow-up doc or rule update: Keep manual runtime deploys using `runtime-backend-key=iac/environments/test-runtime/terraform.tfstate`, and keep the runtime module allowing service-to-service ingress from the shared runtime security group on each exposed application port.

### 2026-04-20 - De-scope inherited non-blocking Sonar noise before disabling broader security signal

- Context: The cloud-build proof-of-concept slice reached a healthy push-to-main deploy path, but the InstechSandbox verifier forks were still generating repeated SonarCloud failure emails from inherited upstream workflows.
- What happened: The deploy-critical gates were already the repo-native validation and publish flows, while the inherited Sonar workflows were failing outside the accepted proof-of-concept acceptance path. At the same time, SCA and secret-scanning were still succeeding and provided useful signal.
- Reusable lesson: When inherited governance workflows create noise during a narrowly scoped proof-of-concept, disable the smallest non-blocking source of noise first rather than turning off all security checks. Preserve manual re-run capability and keep higher-signal checks enabled where they are not impeding delivery.
- Follow-up doc or rule update: Keep the InstechSandbox verifier forks on manual-only SonarCloud during the current proof-of-concept phase, while retaining automatic SCA and secret-scanning until there is evidence they are also materially obstructing the agreed platform goal.

### 2026-04-19 - ECS secret refs require explicit Parameter Store access on the task execution role

- Context: After the issuer-backend moved its signer material into ECS secret references, the public `test` runtime still failed to start the service even though the container image and runtime config were correct.
- What happened: The ECS task never reached container startup. Service events showed `ResourceInitializationError` because the shared `test-ecs-task-execution` role only had `AmazonECSTaskExecutionRolePolicy`, which did not allow `ssm:GetParameters` on the new `/test/runtime/issuer-backend/*` SecureString parameters.
- Reusable lesson: In this runtime scaffold, switching from tracked files to SSM-backed secret refs is a two-part change: wire the manifest secret references and extend the execution role so ECS can fetch them before container launch. Otherwise the service fails before logs ever reach the application container.
- Follow-up doc or rule update: Keep the test runtime execution role allowed to read `/${environment}/runtime/*` Parameter Store entries and decrypt them via SSM whenever reviewed runtime-config manifests use ECS secret references.

### 2026-04-19 - Verifier backend needs a longer ALB grace period than the rest of the runtime slice

- Context: The public `test` verifier-backend rollout stayed `IN_PROGRESS` for over an hour even though new tasks were starting and the container process itself was not crash-looping.
- What happened: ECS was configured with a uniform `120` second `health_check_grace_period_seconds` for all public-ingress services. The verifier backend spends longer than that bootstrapping trust-list validation before `/actuator/health` can pass, so each replacement task was terminated by the service scheduler with `Task failed ELB health checks` before it could ever take over.
- Reusable lesson: A shared runtime module can still need per-service readiness budgets. When a service has a known cold-start phase longer than the generic ALB grace period, encode that exception in infrastructure rather than relying on retries to eventually line up.
- Follow-up doc or rule update: Keep `verifier-backend` on a `240` second ECS health-check grace period in the test runtime module until startup work is reduced or health checks are redesigned.

### 2026-04-19 - Cloud ECS images must not depend on ignored local proof assets

- Context: The public `test` issuer-backend ECS rollout remained stuck in `IN_PROGRESS` with repeated `EssentialContainerExited` task failures even after image publish and deploy automation were working.
- What happened: The runtime renderer pointed `TRUSTED_CAS_PATH`, `PRIVKEY_PATH`, `NONCE_KEY`, and `CREDENTIAL_KEY` at `/app/local/*`, but those files only existed in the developer workspace and were ignored by git. GitHub-built images therefore started without signer assets, crashed on `os.listdir('/app/local/cert/')`, and never reached steady state.
- Reusable lesson: If a cloud task depends on protocol-facing signer files, treat them as explicit runtime contract, not accidental workspace baggage. Put fixed trust material behind reviewed ECS secret references, bootstrap it into writable runtime paths before app startup, and generate only the ephemeral keys that do not need cross-service trust continuity.
- Follow-up doc or rule update: Keep issuer cloud runtime config using secret-backed bootstrap for the Utopia signer assets and writable temp paths for generated request-encryption and nonce keys. Do not point ECS at ignored repository directories like `/app/local/*` again.

### 2026-04-18 - Local cert refresh must treat a missing IACA as stale signer state

- Context: The rebuilt local Emerald Insurance proof flow regressed back to `IssuerCertificateIsNotTrusted` after wallet consent, even though this trust-shape issue had already been fixed before.
- What happened: The local runtime only had `PID-DS-0001_UT_cert.pem`, a self-signed DS leaf with the correct issuer SAN, but no `PIDIssuerCALocalUT.pem`. `scripts/refresh-local-certs.sh` validated SANs and key matching, then skipped CA verification when the IACA file was absent, so the stale DS cert was accepted. `scripts/start-local-verifier.sh` then mounted that DS leaf as `VERIFIER_IRISHLIFE_PIDISSUERCHAIN_PATH`, but the verifier expects PKIX trust anchors for SD-JWT issuer validation, not a directly trusted self-signed DS leaf.
- Reusable lesson: In the local stack, absence of the IACA is itself a certificate-staleness signal. Treat missing CA material as a hard failure that forces signer-chain regeneration before starting verifier flows.
- Follow-up doc or rule update: Keep `refresh-local-certs.sh` requiring a present IACA and keep verifier startup refusing DS-leaf fallback for `issuer_chain` so the regression cannot hide behind a green local build.

### 2026-04-15 - Cloud SD-JWT issuer demo certs must bind to the public issuer URL, not the packaged local IP

- Context: The Emerald Insurance proof flow progressed past wallet consent in the public `test` environment and then failed at verifier response processing with `IssuerCertificateIsNotTrusted`.
- What happened: The verifier accepted the posted proof shape but rejected the SD-JWT VC issuer certificate because the embedded `x5c` leaf carried `URI:https://192.168.0.131:5002` and local host entries from the packaged demo Utopia signer assets, while the live issuer metadata advertised `https://issuer-api.test.instech-eudi-poc.com`. The verifier library binds the issuer HTTPS identity to SAN URI or SAN DNS values on the credential leaf certificate, so the stale local SAN caused proof rejection even though the public ingress TLS certificate was correct.
- Reusable lesson: In this proof-of-concept stack, the SD-JWT signer leaf certificate is protocol-facing data, not just local packaging detail. Any cloud deployment that reuses the packaged demo signer assets must rewrite or replace the DS leaf certificate so its SAN matches the configured public issuer URL before credentials are issued.
- Follow-up doc or rule update: Keep the issuer backend startup path aligning the packaged Utopia DS certificate SAN with `SERVICE_URL`, and treat verifier-side SAN failures against the issuer URL as an issuer asset/config mismatch before changing verifier trust logic.

### 2026-04-16 - Public issuer regressions can come from deploying the right repo name but the wrong build context

- Context: The public issuer browser journey started returning page-not-found at `credential_offer_choice` immediately after an issuer-backend rollout, even though the backend task definition, ALB host rules, and public service URLs looked correct.
- What happened: The backend ECS service was updated to an image tag that had been built from the frontend repository working tree by mistake. Because both services are Flask apps on the same internal port and both publish similar landing pages and discovery-style responses, the issue first looked like host-routing drift or a route regression instead of an image provenance problem.
- Reusable lesson: For multi-repo services with similar runtime shapes, a successful image push and healthy ECS rollout are not enough evidence that the right app was deployed. Promotion needs one provenance check that ties the image to the intended source repo and one backend-only smoke check that the frontend image cannot satisfy.
- Follow-up doc or rule update: Keep issuer rollouts verifying the pushed digest against the running ECS task and probing a backend-only route such as `issuer-api/.../credential_offer_choice` before declaring the public browser path ready to retest.

### 2026-04-16 - Public verifier SD-JWT proof needs an explicit Emerald Insurance issuer-chain trust anchor

- Context: After the issuer-side SAN rewrite fix and a fresh JWT PID issuance, both Emerald Insurance proof journeys in the public `test` environment still failed on the verifier side with `IssuerCertificateIsNotTrusted`.
- What happened: Temporary verifier logging first showed both flows were running with `issuerChainConfigured=false`. After the cloud runtime was corrected, the same trust failure remained. Correlated issuer-side logging then proved why: the issuer currently embeds a self-signed SD-JWT leaf with `subject=CN=Local Utopia DS` and `issuer=CN=Local Utopia DS` while the verifier had been configured to trust the Utopia issuer CA. A CA trust anchor cannot validate that self-signed leaf.
- Reusable lesson: For these public Emerald Insurance proof flows, trust shape matters as much as trust presence. If the issuer emits a self-signed SD-JWT leaf, the verifier must either trust that exact leaf or the issuer must be changed to emit a CA-signed public-SAN leaf. Pointing the verifier at the CA while the issuer emits a self-signed DS certificate is a guaranteed failure.
- Follow-up doc or rule update: Keep the public verifier runtime wiring aligned with the issuer's actual SD-JWT certificate shape. The current emergency setting is `VERIFIER_IRISHLIFE_PIDISSUERCHAIN_PATH=classpath:irishlife/LocalUtopiaDsSelfSigned.pem`; replace it with the reviewed issuer CA chain only after cloud signer material allows CA-signed leaf issuance again.

### 2026-04-15 - Do not overstate Android APK device minimums when the repo only proves install-time floors

- Context: The workspace needed a defensible statement of minimum Android device requirements for redistributed wallet APKs.
- What happened: The repository proved `minSdk = 29` and manifest-declared required hardware features, but it did not prove a minimum RAM, storage, CPU, or handset family. A generic "minimum device" claim would therefore overstate what had actually been validated.
- Reusable lesson: Separate install-time requirements from tested runtime evidence. If the codebase only proves Android version floor and manifest-declared hardware features, publish those as the hard requirements and add a `Tested on` declaration for the exact devices and flows exercised.
- Follow-up doc or rule update: Keep Android release records carrying an evidence-backed OS and feature statement plus a tested-on section whenever hardware minimums are not explicitly validated.

### 2026-04-14 - SD-JWT PID issuance must not precreate an mdoc-sized credential pool

- Context: Cloud JWT PID issuance completed successfully on the auth server and issuer backend, including `POST /credential 200`, but the Android wallet still returned a generic issuance error after the browser came back to the app.
- What happened: The wallet's SD-JWT PID issuance rule reused the mdoc-style `numberOfCredentials = 60` setting. In the Android wallet-core SDK, `DocumentManagerImpl.storeIssuedDocument(...)` requires the number of issuer-provided credentials to match the number of precreated pending credentials on the unsigned document. SD-JWT PID issuance returns a single VC, so wallet storage failed after a successful issuer response because the wallet had precreated 60 pending credentials.
- Reusable lesson: Do not assume SD-JWT VC issuance uses the same credential-pool semantics as mdoc. For SD-JWT PID in the current Android wallet stack, precreate one credential unless the issuer and wallet-core explicitly support multi-credential SD-JWT issuance.
- Follow-up doc or rule update: Keep Android wallet issuance rules separate by format. `MdocPid` can retain its current one-time-use credential pool, but `SdJwtPid` should use a single precreated credential until wallet-core and issuer behavior are aligned for larger SD-JWT pools.
- Maintainer guardrail: Leave `DocumentIdentifier.SdJwtPid` at `numberOfCredentials = 1` in both wallet flavors for now. Do not raise it speculatively to values like `10` or `60` for future-proofing. Revisit only when a verified multi-credential SD-JWT issuance path exists end to end and the wallet-core storage contract is confirmed to accept that larger pending-credential pool.

### 2026-04-16 - Reusable SD-JWT PID proofs must not use one-time credential policy with a single credential

- Context: In the public Emerald Insurance verifier flows, the first successful SD-JWT PID proof consistently caused the next and all subsequent proofs to fail with the wallet reporting no available requested documents.
- What happened: Android wallet-core builds SD-JWT proofs through `verifiablePresentationForSdJwtVc()`, which calls `IssuedDocument.consumingCredential()`. In the document-manager library, `consumingCredential()` applies the document credential policy after a successful proof. With `CredentialPolicy.OneTimeUse`, it deletes the credential. The app was configuring `DocumentIdentifier.SdJwtPid` as `OneTimeUse` with `numberOfCredentials = 1`, so the first successful proof deleted the only usable SD-JWT PID credential and every later proof failed at `findCredential() != null`.
- Reusable lesson: For reusable SD-JWT PID verifier journeys in the current Android wallet stack, a single issued credential must use `CredentialPolicy.RotateUse`, not `OneTimeUse`. One-time-use only works when the issuance path actually provisions a pool of independent credentials sized for the intended number of presentations.
- Follow-up doc or rule update: Keep `DocumentIdentifier.SdJwtPid` on `CredentialPolicy.RotateUse` with `numberOfCredentials = 1` in both Demo and Dev configs unless and until the issuer and wallet/document-manager stack support multi-credential SD-JWT issuance for one-time-use rotation.

### 2026-04-13 - Wallet issuance auth return needs a replay path, not only a live broadcast

- Context: The Android wallet could complete a local authorization activity and return to `MainActivity`, yet the JWT PID issuance UI sometimes stayed stuck or silently failed to advance even though the app had already bounced back from the auth WebView.
- What happened: The issuance auth return was delivered as `VCI_RESUME_ACTION`, an in-memory broadcast emitted immediately when the activity handled the issuance deep link. If `AddDocumentScreen` or `DocumentOfferScreen` was not yet mounted and listening, that broadcast was lost. Both screens already replayed cached pending deep links on `ON_RESUME`, but their viewmodels ignored cached `ISSUANCE` deep links, so there was no fallback resume path.
- Follow-on finding: Even after caching and replaying the issuance URI, the dashboard route still dropped `DeepLinkType.ISSUANCE` returns because it only reopened presentation and credential-offer flows. On devices where the app resumed to the dashboard before issuance screens remounted, JWT PID issuance could still fail while the cloud issuer had already completed successfully.
- Final fix shape: When dashboard consumes a cached `ISSUANCE` deep link, the generic deep-link helper must re-cache that URI and navigate back into `ISSUANCE_ADD_DOCUMENT` using the existing issuance arguments. Re-broadcasting `VCI_RESUME_ACTION` from dashboard is still race-prone because the issuance screen may not be mounted yet.
- Reusable lesson: For wallet issuance resumption, treat the authorization-return URI as resumable state, not as a fire-and-forget UI event. Cache it long enough for the issuance screen to replay on resume, and make the screen-level deep-link handler able to consume `ISSUANCE` links directly.

### 2026-04-13 - Cloud issuer revocation URLs must never fall back to local `.env`

- Context: The issuer backend container loads `app/.env` at startup, including revocation settings intended for local development.
- What happened: In cloud, missing ECS overrides for revocation URLs caused fallback to the local `https://${MYIP}:${ISSUER_PORT}/token_status_list/*` values, which resolved to a private LAN IP and added 30-second issuance delays until the internal credential-generation call timed out.
- Reusable lesson: Treat revocation URL overrides as required cloud runtime config, not optional defaults.

### 2026-04-13 - Cloud verifier UI must proxy backend API paths, not just serve the SPA

- Context: The public Emerald Insurance agent page on `verifier.test.instech-eudi-poc.com` showed `Failed to create or invite the case.` even though the verifier backend routes were present and healthy on `verifier-api.test.instech-eudi-poc.com`.
- What happened: The Angular UI issued same-origin requests such as `POST /ui/irish-life/new-business/cases`, but the cloud Nginx container only served static assets and had no `/ui` reverse proxy. Those requests therefore died in the UI container with `405 Method Not Allowed` before the Kotlin backend saw them.
- Reusable lesson: When a frontend is built around relative API paths, the cloud UI container must preserve the same reverse-proxy contract as local development. Rewriting a few absolute URLs is not enough if the browser can still call `/ui`, `/wallet`, or `/utilities` on the SPA origin.

### 2026-04-21 - Private ECS DNS in Nginx must be re-resolved after backend task rotation

- Context: All four live Emerald Insurance verifier journeys began timing out again even though `test-verifier-backend` was healthy and the direct backend host `verifier-api.test.instech-eudi-poc.com` still answered quickly.
- What happened: The verifier UI task was configured with `HOST_API=http://test-verifier-backend.test.runtime.internal:8080`, but Nginx had resolved that hostname only when the UI container started. After the backend redeployed, Cloud Map pointed at the new backend IP while the UI task kept proxying to the stale old IP, producing `504 Gateway Time-out` and log lines such as `upstream timed out ... upstream: "http://10.42.1.123:8080/..."`.
- Reusable lesson: For ECS-to-ECS proxying through private DNS, Nginx must use a resolver-backed variable target so it can refresh backend IPs after task rotation. Otherwise a healthy backend redeploy can silently break a long-lived UI task until the UI service is restarted.
- Follow-up doc or rule update: Keep the runtime runbook explicit that `test-verifier-ui` can be recovered immediately with `aws ecs update-service --force-new-deployment`, but treat that only as the operational workaround. The durable fix is dynamic DNS resolution in the UI proxy config.

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
- What happened: That produced a coherent demo technically, but it inverted the intended ownership model and weakened the credibility of the automated checks because the verifier was matching against agent-entered data instead of an internal Emerald Insurance policy record.
- Reusable lesson: If a journey is described as customer-driven and automated, the verifier must own the comparison baseline server-side and treat the agent surface as a monitor unless manual intervention is explicitly part of the design.
- Follow-up doc or rule update: Keep policy, account, and comparison-record lookup in the backend for Existing Business-style journeys, and avoid building operator forms that become the de facto source of truth.

### 2026-04-10 - Customer entry surfaces must not imply business-reference lookup unless the backend supports it

- Context: The Emerald Insurance customer-entry pages invited users to enter a case or claim reference, but the implemented routes actually load journeys by internal verifier case ID only.
- What happened: The wording drifted ahead of the real backend capability, which risked sending operators or customers down a path that could never resolve successfully without an additional lookup endpoint.
- Reusable lesson: Entry-page language is part of the contract. If a verifier flow is keyed by internal case ID, the UI must say so explicitly until a real business-identifier lookup exists.
- Follow-up doc or rule update: Keep Emerald Insurance entry forms aligned with the actual backend lookup capability, and do not use policy reference or claim reference wording on direct-entry pages unless those identifiers are truly resolvable.

### 2026-04-06 - Same-device Emerald Insurance mismatch outcomes must be finalized server-side

- Context: After wallet Share completed with intentionally mismatched PID data, the agent view still had no terminal `FAILED` outcome unless the customer browser also returned through the Angular callback path.
- What happened: The actual field comparison logic for given name, family name, birth date, address, and expiry only ran in the customer UI after loading the wallet response with `response_code`. That meant a submitted same-device proof could exist in verifier storage while the backend case state still lacked the final mismatch evaluation.
- Reusable lesson: In same-device verifier journeys, business-critical proof matching must not depend on a frontend redirect callback. Once the wallet response is stored, the verifier backend must be able to derive and persist the terminal case outcome on its own.
- Follow-up doc or rule update: Keep Emerald Insurance case refresh and completion flows capable of validating stored PID responses server-side so agent polling can reach `FAILED` or `COMPLETED` without a customer-page round trip.

### 2026-04-06 - Emerald Insurance SD-JWT claim reconstruction must read JSON values, not Kotlin strings

- Context: A live Emerald Insurance PID presentation included disclosed `given_name`, `family_name`, `birthdate`, and `date_of_expiry`, but the case summary still stored an empty `claimsSnapshot` and reported all fields as mismatched.
- What happened: The verifier reconstructed SD-JWT claims into a `JsonObject`, but the Emerald Insurance matcher treated that payload like `Map<String, Any?>` and only accepted raw Kotlin `String` values. As a result, every disclosed JSON primitive was read as blank, producing false mismatch and expiry failures.
- Reusable lesson: When verifier-side business logic consumes reconstructed SD-JWT claims, treat the payload as structured JSON and convert `JsonPrimitive` values explicitly instead of assuming JVM-native string types.
- Follow-up doc or rule update: Keep Emerald Insurance validation and similar verifier-side proof matching paths aligned with the SD-JWT library's `JsonObject` output so persisted `claimsSnapshot` data reflects the actual disclosed claims.

### 2026-04-06 - Emerald Insurance PID address requests must not rely only on `address.formatted`

- Context: After fixing SD-JWT claim extraction, a fresh Emerald Insurance proof matched name, family name, birth date, and expiry, but address still failed even though the issued PID contained structured address data.
- What happened: The Emerald Insurance verifier requested only `address.formatted`, while the locally issued PID exposed address fields such as `street_address`, `locality`, `region`, `postal_code`, and `country` without a `formatted` value. The wallet therefore disclosed no address claim for the verifier to compare.
- Reusable lesson: For local PID interoperability, request structured address sub-fields in addition to any convenience field like `address.formatted`, then reconstruct the comparison string server-side.
- Follow-up doc or rule update: Keep Emerald Insurance DCQL PID requests aligned with the actual local issuer payload shape and record disclosed claim paths in failed-case snapshots so missing address fields are visible without decoding presentation events manually.

### 2026-04-06 - Failed verifier journeys should render compared values, not only generic mismatch text

- Context: The Emerald Insurance UI could already show that address validation failed, but the frontend did not reveal which application value was compared against which disclosed wallet value.
- What happened: The backend persisted a `claimsSnapshot` with the reconstructed disclosed values and claim paths, yet the UI rendered only generic lines such as `Address did not match the application.`. That left operators without enough evidence to distinguish a true mismatch from a missing disclosure.
- Reusable lesson: When the verifier persists field-level validation evidence, surface that evidence in the journey UI so failed cases can be triaged without backend log access.
- Follow-up doc or rule update: Keep Emerald Insurance failure states rendering application-versus-wallet comparison details from the persisted validation snapshot, especially for address mismatches and missing structured claim disclosures.

### 2026-04-07 - Local proof-of-address matching should tolerate punctuation-only address differences

- Context: The local Emerald Insurance proof-of-address flow reconstructs address from structured PID claims, but operators may type the same address into New Business with harmless punctuation or postal-code spacing differences.
- What happened: The verifier already normalized punctuation and repeated whitespace, but values such as `D02 XY56` versus `D02XY56` could still fail because internal whitespace remained significant.
- Reusable lesson: For local PID address proof matching, keep the comparison strict on underlying values but tolerant of punctuation-only and whitespace-only formatting differences inside the final address string.
- Follow-up doc or rule update: Keep Emerald Insurance address matching aligned with the structured PID address fields and normalize compact address tokens before treating a local demo case as failed.

### 2026-04-07 - Local Emerald Insurance address proof should not depend on `address.country`

- Context: A local issuance/proof run reported that the country code was not part of the disclosed PID proof, even though the verifier was still requesting and reconstructing address with `address.country`.
- What happened: This made the local proof-of-address path more fragile than it needed to be, because the verifier depended on one more structured field than the local demo needed to prove the core address match.
- Reusable lesson: For the local Emerald Insurance PID demo, keep the required structured address subset minimal and stable: `street_address`, `locality`, `region`, and `postal_code`.
- Follow-up doc or rule update: Keep `address.country` optional in issuance UX, but do not require it in the Emerald Insurance verifier request or reconstructed comparison string.

### 2026-04-07 - Emerald Insurance demo surfaces should use Emerald Insurance blue/white branding, not inherited verifier green

- Context: The Emerald Insurance New Business verifier journey had been functionally tailored, but the landing, agent, and customer surfaces still used the generic verifier green/gold treatment.
- What happened: The palette looked like a default verifier theme rather than an Emerald Insurance-specific journey, which weakened demo credibility even though the protocol flow itself was correct.
- Reusable lesson: For branded verifier demos, visual treatment is part of the journey contract. Once a flow is presented as Emerald Insurance-specific, the UI should use Emerald Insurance-aligned blue/white tones instead of inherited product colors.
- Follow-up doc or rule update: Keep Emerald Insurance verifier surfaces on a consistent blue/white palette across selector, agent, and customer pages, and avoid reintroducing generic verifier green in those routes.

## Seed Entries

### 2026-04-12 - Reserve wallet Dev for local readers and Demo for cloud readers

- Context: The local orchestration wrappers were still building and installing the Android `Demo` flavor even though the cloud-build workstream also needs `Demo` to mean the shared public tester build.
- What happened: That made the local-versus-cloud split ambiguous and encouraged operators to reuse one wallet APK across incompatible reader environments. It also hid the fact that the two wallet installs should stay side by side with different app names and distinct package or bundle identifiers.
- Reusable lesson: In the mobile repos, environment semantics should be explicit. Keep `Dev` for local reader and verifier work, keep `Demo` for shared cloud tester work, and make the launcher names visibly different so operators do not confuse them on-device.
- Follow-up doc or rule update: Keep local build wrappers targeting Android `Dev`, keep Android or iOS tester publication targeting `Demo`, and document that document-reader flows are environment-bound rather than interchangeable across local and cloud builds.

### 2026-04-12 - Frontend credential offers must refresh live issuer metadata after startup fallbacks

- Context: The public issuer frontend came up while the issuer API was still unhealthy, then continued rendering the credential-offer page without `PID (SD-JWT VC)` even after the issuer metadata endpoint was later fixed.
- What happened: Frontend startup fetched issuer metadata once, fell back to the bundled local credential JSON set on error, and kept serving that incomplete in-memory list for the lifetime of the process. The fallback bundle also lacked a `pid_vc_sd_jwt` entry, so the offer page only showed mdoc credentials.
- Reusable lesson: Credential-offer surfaces should not treat startup-time issuer metadata as immutable. Refresh live metadata at render time when practical, and keep the bundled fallback set aligned with the real issuer metadata so temporary startup races do not create persistent UI drift.
- Follow-up doc or rule update: Keep the issuer frontend credential-offer path able to refresh `credential_configurations_supported` from the issuer on demand, and maintain the fallback credential metadata bundle with both mdoc and SD-JWT PID entries.

### 2026-04-12 - Drive iOS issuer hosts from variant xcconfig

- Context: The wallet display names and Dev-versus-Demo intent were already separated, but the iOS wallet still hardcoded upstream issuer hosts in `WalletKitConfig.swift`.
- What happened: That left the workspace with a naming split but not a real local-versus-public issuer split, and any physical-device local testing risked pushing a machine-specific LAN host into tracked source files.
- Reusable lesson: For iOS wallet environment targeting, feed issuer frontend and backend URLs from variant xcconfig into `Wallet.plist`, let `WalletKitConfig.swift` consume those values, and keep any device-specific LAN override in an ignored local xcconfig file rather than committing per-machine hosts.
- Follow-up doc or rule update: Keep `Dev` defaulted to local issuer URLs, keep `Demo` defaulted to the public `test.instech-eudi-poc.com` issuer URLs, and preserve `Wallet/Config/WalletLocalOverrides.xcconfig` as the local-only escape hatch for physical-device testing.

### 2026-04-11 - Optional integrations must not fail shared health checks in first public slices

- Context: The first public verifier slice came up with Route 53, ACM, ALB, and ECS, but the verifier backend still failed the ALB health check even though the process itself was running.
- What happened: Spring Boot exposed mail health through the shared `/actuator/health` endpoint while the verifier runtime still used placeholder SMTP settings for an optional invite-email integration. The ALB therefore saw the backend as unhealthy and returned `503` even though the core verifier APIs were otherwise available.
- Reusable lesson: In first public slices, optional integrations such as outbound email must not participate in the primary load-balancer health contract unless their real cloud credentials are provisioned.
- Follow-up doc or rule update: Keep generated runtime-config profiles able to disable optional mail health contributors until the corresponding SMTP configuration is intentionally enabled.

### 2026-04-11 - Cloud runtime defaults must not assume local writable paths or local mount points

- Context: The first full public issuer deployment scaled all issuer services to one task each, but the auth server and issuer backend still failed immediately after startup in ECS.
- What happened: The auth server kept a template `logging.FileHandler` target under `/tmp/oidc_log_dev/logs.log` without ensuring that directory existed in the container, while the issuer backend still defaulted to `/etc/eudiw/pid-issuer/...` trust and key paths even though the proof-of-concept image packaged its demo assets under the application tree.
- Reusable lesson: When promoting a local-first service into the first cloud runtime, convert every startup-critical path into an explicit runtime contract. Writable log paths, trust stores, and signing-key locations must not depend on developer-machine mount points or undeclared local directory conventions.
- Follow-up doc or rule update: Keep the public runtime-config generator responsible for passing explicit auth log-file and issuer asset paths that match the current packaged image layout, and treat path mismatches as deployment-contract bugs rather than infrastructure noise.

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

- Context: The Emerald Insurance verifier created a valid SD-JWT PID request on the LAN URL, but the Android wallet still failed before the consent screen and returned only a generic in-app error.
- What happened: The wallet was already configured for the local pre-registered verifier id `Verifier`, but the installed APK had been built with a stale `LOCAL_VERIFIER_API` pointing at an older LAN IP. The wallet could fetch the deep link, then still fail before consent because its pre-registered verifier metadata no longer matched the live verifier URL.
- Reusable lesson: When local verifier or issuer hosts are compiled into the wallet, a LAN IP change requires a wallet rebuild and reinstall, not just a service restart.
- Follow-up doc or rule update: Keep wallet install wrappers aligned with the current `localDemoHost`, and fail fast if the built APK still targets an older verifier URL.

### 2026-04-14 - DemoDebug local builds must not inherit cloud verifier trust metadata

- Context: The Emerald Insurance local verifier returned a valid request object and the wallet held a PID with the requested address values, but proof still failed before consent submission.
- What happened: The installed DemoDebug wallet fetched the local request object from the LAN verifier, then validated it against `https://verifier.test.instech-eudi-poc.com/wallet/public-keys.json` because the demo flavor still defaulted `VERIFIER_API` to the cloud verifier. The install wrapper only checked `LOCAL_VERIFIER_API`, so it falsely reported the APK as aligned even though the wallet's preregistered verifier trust metadata still pointed at cloud.
- Reusable lesson: For this local Emerald Insurance workspace, DemoDebug must default to local verifier and issuer endpoints unless an explicit demo override is supplied. Wrapper validation must check the generated `VERIFIER_API` field that the wallet actually uses for preregistered verifier trust.
- Follow-up doc or rule update: Keep the wallet demo build defaults local-first in this workspace and reserve explicit `demo*` overrides for workflows that intentionally target cloud endpoints.

### 2026-04-03 - Local issuance trust must cover every self-call path

- Context: The Emerald Insurance SD-JWT local issuance flow had already been fixed for frontend metadata startup order, wallet trust, and auth-server attester trust, but the wallet still failed after returning from browser authorization.
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

### 2026-04-04 - Local Emerald Insurance SD-JWT proofs need an explicit PID issuer chain

- Context: The Emerald Insurance case API created same-device PID proof requests without using the verifier UI's manual trusted-issuer control, and proof sharing still failed after the local signer cert itself had been fixed.
- What happened: The verifier only had default trust-source rules for age-verification documents, so SD-JWT PID validation in the Emerald Insurance flow still had no trusted issuer chain unless one was passed in the transaction init request. The wallet could fetch the request object and reach Share, then direct-post failed with `IssuerCertificateIsNotTrusted` because the transaction carried no PID `issuer_chain`.
- Reusable lesson: When a local verifier journey bypasses the manual trusted-issuer UI, the flow itself must supply the issuer chain or an equivalent verifier-side trust source for the requested VCT. In the Emerald Insurance PID flow that `issuer_chain` is parsed as PKIX trust anchors, so the correct local input is the issuer CA PEM, not the DS leaf PEM embedded into the SD-JWT.
- Follow-up doc or rule update: Mount the local PID issuer CA PEM into the verifier runtime and inject it into Emerald Insurance transaction init requests. Keep the DS PEM only as a compatibility fallback, and restart the verifier whenever the local IACA or DS signer material changes.

### 2026-04-05 - Agent spinners need browser-side guardrails even after backend fixes

- Context: The Emerald Insurance `Create case and send invite` action had already been fixed server-side for placeholder SMTP hangs, but the agent page could still be left showing a spinner with no visible progress when the browser-side request chain stalled.
- What happened: The deployed Angular build was current and same-origin, so the remaining failure mode was a frontend wait state that gave the operator no clue whether case creation or invite dispatch was still outstanding. That made retry behavior unsafe because the backend might already have completed one of the two steps.
- Reusable lesson: For multi-step local orchestration flows, do not rely on a single generic busy flag. Show the active step and add a browser-side timeout that tells the operator to refresh current state before retrying.
- Follow-up doc or rule update: Keep the Emerald Insurance agent UI aligned with backend state by labeling the active step and treating a long browser wait as a recoverable UI condition rather than an infinite spinner.

### 2026-04-05 - Terminal proof outcomes must render from persisted case state

- Context: The Emerald Insurance customer proof page could complete or fail a proof evaluation, but a later reload or re-entry could lose the in-memory transaction object that originally drove the success or failure banner.
- What happened: The customer page only rendered the terminal result banner when it still held a live `concludedTransaction`, even though the backend already persisted `FAILED`, `failureReason`, and field-match validation details on the case summary. That made mismatched proofs easy to miss because the screen could reopen without a clear terminal outcome.
- Reusable lesson: For verifier journeys, user-facing terminal states must be derived from persisted backend case state, not only transient browser callback state.
- Follow-up doc or rule update: Keep Emerald Insurance customer pages rendering `COMPLETED` and `FAILED` outcomes directly from case summary data, including persisted mismatch reasons.

### 2026-04-06 - Agent status polling must tolerate transient refresh failures

- Context: In the Emerald Insurance New Business flow, an agent can create a case and leave the page open while the customer completes or fails proof sharing elsewhere.
- What happened: The agent page relied on a simple polling subscription with no error handling. Any single failed `getCase` request could terminate polling silently, leaving the UI stuck on the last seen state such as `INVITE_SENT` even though the backend case had already moved to `FAILED` or `COMPLETED`.
- Reusable lesson: Long-running verifier status polling must treat refresh failures as recoverable and continue polling unless the case reaches a terminal state.
- Follow-up doc or rule update: Keep the Emerald Insurance agent UI surfacing transient refresh errors while allowing polling to continue until a terminal case status is observed.

### 2026-04-06 - Same-device case polling must not depend on response_code once the wallet response is stored

- Context: In the Emerald Insurance unhappy path, the customer completed Share on the wallet, but the support-agent page stayed at `INVITE_SENT`.
- What happened: The agent page polls case status through backend `GET /cases/{caseId}` calls, which in turn refresh the case from the stored wallet response using `getWalletResponse(transactionId, null)`. The verifier runtime treated a submitted same-device presentation as unavailable unless the original `response_code` was provided, so the case refresh never saw the stored wallet response and the agent page remained stuck before `PROOFS_RECEIVED`.
- Reusable lesson: Once a wallet response has already been persisted for a submitted presentation, backend case refresh logic must be able to observe it without requiring the same-device redirect `response_code` again.
- Follow-up doc or rule update: Keep Emerald Insurance support-agent polling and any similar backend case refresh path compatible with submitted same-device presentations after the original customer redirect has finished.

### 2026-04-09 - Local mdoc signer chains should target the strictest wallet validator

- Context: The Emerald Insurance local issuer stack was exercised against both Android and iPhone wallets for PID mdoc issuance while using local LAN services and self-signed transport TLS.
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

- Context: Multiple isolated workspaces were created for Emerald Insurance verifier, iOS wallet, and cloud build work using local `wip/<stream>` branches.
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

- Context: The Emerald Insurance New Business design needed a proof-of-address credential and the issuer metadata exposed a `por` credential identifier.
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

# Stakeholder Wallet Demo Guide

This note is the shortest practical guide for external testers and business stakeholders who need to:

- install the correct Android wallet APK
- issue a credential against the public cloud issuer
- use that credential in the public Irish Life verifier journeys

It is intentionally a one-page operator guide, not a second technical runbook.

The detailed engineering source of truth remains:

- [Reference Implementation Standards Summary](Reference_Implementation_Standards_Summary.md)
- [Irish Life Public Cloud Architecture](Irish_Life_Public_Cloud_Architecture.md)
- [Cloud Build And Deployment Runbook](Cloud_Build_Deployment_Runbook.md)
- [Irish Life New Business Verifier Design](Irish_Life_New_Business_Verifier_Design.md)
- [Irish Life Existing Business Verifier Design](Irish_Life_Existing_Business_Verifier_Design.md)

## Scope

Use this guide only for the public cloud proof-of-concept environment.

- Wallet build: Android `Demo` APK from GitHub Releases
- Environment: public `test` subdomains under `*.test.instech-eudi-poc.com`
- Journeys covered:
  - Irish Life New Business
  - Irish Life Existing Business
Do not use a local `Dev` APK for this flow.
- Public demo URLs:
  - Irish Life verifier journey selector: `https://verifier.test.instech-eudi-poc.com/irish-life`
  - Irish Life New Business customer entry: `https://verifier.test.instech-eudi-poc.com/irish-life/new-business/customer`
  - Irish Life Existing Business customer entry: `https://verifier.test.instech-eudi-poc.com/irish-life/existing-business/customer`
  - Irish Life Existing Business monitor: `https://verifier.test.instech-eudi-poc.com/irish-life/existing-business/agent`
  - Issuer frontend: `https://issuer.test.instech-eudi-poc.com/`

## 1. Get The APK

Use the newest `Latest` release in the Android wallet fork:

- Repository: `InstechSandbox/eudi-app-android-wallet-ui`
- Releases page: `https://github.com/InstechSandbox/eudi-app-android-wallet-ui/releases`

Download the signed Android `demoRelease` APK from the latest release assets.

The current publication model uses an automatically generated release name similar to:

- `Demo main release r<run-number> (<short-sha>, vc<versionCode>)`

## 2. Install The APK On Android

1. Download the APK to the Android device.
2. Open the APK from the device downloads area.
3. If Android blocks the install, temporarily allow installs from that source.
4. Complete the installation.
5. Open the installed wallet app.

If an older demo wallet is already installed, remove it first to avoid confusion about which build is being tested.

## 3. Issue A PID Credential

Use the public issuer frontend and issue a `PID (SD-JWT VC)` credential in the wallet.

Follow this exact order:

1. Open `https://issuer.test.instech-eudi-poc.com/`
2. Click the credential offer link shown on the page to start issuance.
3. When the issuer asks you to choose a credential type or format, select:
   - `PID`
   - format: `SD-JWT VC`
   - country of origin: `FormEU`

For the Irish Life happy path, the wallet credential needs these structured address claims populated:

1. `street_address`
2. `locality`
3. `region`
4. `postal_code`

For the simplest happy-path test data, issue a PID with:

1. `given_name = Patrick`
2. `family_name = Murphy`
3. `birthdate = 1980-04-12`
4. enter `country = IE`
5. click `Add Optional Attributes`
6. choose `Address`
7. click `Add Attributes`
8. enter `street_address = 1 Main Street`
9. enter `locality = Dublin`
10. enter `region = Leinster`
11. enter `postal_code = D02 XY56`

This produces the expected joined address:

`1 Main Street, Dublin, Leinster, D02 XY56`

## 4. Run The Irish Life Existing Business Journey

This is the most fixed and prescriptive happy path.

1. Open `https://verifier.test.instech-eudi-poc.com/irish-life/existing-business/customer`
2. Review the withdrawal request page.
3. Continue into wallet sharing when prompted.
4. Complete wallet sharing on your phone.

The Existing Business demo currently accepts only policy number `12345678` behind the prepopulated journey.

For a successful match, the issued PID must match this internal policy record:

1. `given_name = Patrick`
2. `family_name = Murphy`
3. `birthdate = 1980-04-12`
4. `address = 1 Main Street, Dublin, Leinster, D02 XY56`

If you want a monitoring view during the demo, open:

- `https://verifier.test.instech-eudi-poc.com/irish-life/existing-business/agent`

That page is read-only for the current demo.

## 5. Run The Irish Life New Business Journey

1. Open `https://verifier.test.instech-eudi-poc.com/irish-life/new-business/customer`
2. Open the customer journey and continue to wallet sharing when prompted.
3. Complete wallet sharing on your phone.

For New Business, the easiest rule is simple:

- whatever personal details and address are entered into the Irish Life New Business case must match the PID disclosed from the wallet

To avoid avoidable mismatch during stakeholder demos, reuse the same values as the issued happy-path PID:

1. given name: `Patrick`
2. family name: `Murphy`
3. birth date: `1980-04-12`
4. current address: `1 Main Street, Dublin, Leinster, D02 XY56`

## 6. Demo Tips

- Use the newest `Latest` APK release, not an older install already on the phone.
- Use the cloud `Demo` APK, not a local `Dev` build.
- For Existing Business, only policy number `12345678` is expected to succeed.
- For both Irish Life journeys, matching is driven by the disclosed PID values.
- Address matching uses the structured PID address fields and reconstructs the value in this order: street, locality, region, postal code.

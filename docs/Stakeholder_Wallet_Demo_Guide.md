# Stakeholder Wallet Demo Guide

This note is the shortest practical guide for external testers and business stakeholders who need to:

- install the correct Android wallet APK
- issue a credential against the public cloud issuer
- use that credential in the public Irish Life verifier journeys

It is intentionally a one-page operator guide, not a second technical runbook.

The detailed engineering source of truth remains:

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

## 3. Public Demo URLs

These are the public cloud endpoints relevant to the demo:

- Irish Life verifier journey selector: `https://verifier.test.instech-eudi-poc.com/irish-life`
- Irish Life New Business customer entry: `https://verifier.test.instech-eudi-poc.com/irish-life/new-business/customer`
- Irish Life Existing Business customer entry: `https://verifier.test.instech-eudi-poc.com/irish-life/existing-business/customer`
- Irish Life Existing Business monitor: `https://verifier.test.instech-eudi-poc.com/irish-life/existing-business/agent`
- Issuer frontend: `https://issuer.test.instech-eudi-poc.com/`

## 4. Issue A PID Credential

Use the public issuer frontend and issue a `PID (SD-JWT VC)` credential in the wallet.

When the issuer asks you to choose a credential type or format, select:

- `PID`
- format: `SD-JWT VC`
- country of origin: `FormEU`

For the Irish Life happy path, the wallet credential needs these structured address claims populated:

1. `street_address`
2. `locality`
3. `region`
4. `postal_code`

If the issuer form exposes optional address fields behind `Add Optional Attributes`, expand that section and populate them there.

For the simplest happy-path test data, issue a PID with:

1. `given_name = Patrick`
2. `family_name = Murphy`
3. `birthdate = 1980-04-12`
4. enter `country = IE`
5. after entering those identity fields, click `Add Optional Attributes`
6. choose `Address`
7. click `Add Attributes`
8. enter `street_address = 1 Main Street`
9. enter `locality = Dublin`
10. enter `region = Leinster`
11. enter `postal_code = D02 XY56`

This produces the expected joined address:

`1 Main Street, Dublin, Leinster, D02 XY56`

## 5. Run The Irish Life Existing Business Journey

This is the most fixed and prescriptive happy path.

1. Open `https://verifier.test.instech-eudi-poc.com/irish-life/existing-business/customer`
2. Enter policy number `12345678`
3. Start the withdrawal request
4. Complete wallet sharing when prompted

The Existing Business demo currently accepts only that policy number.

For a successful match, the issued PID must match this internal policy record:

1. `given_name = Patrick`
2. `family_name = Murphy`
3. `birthdate = 1980-04-12`
4. `address = 1 Main Street, Dublin, Leinster, D02 XY56`

If you want a monitoring view during the demo, open:

- `https://verifier.test.instech-eudi-poc.com/irish-life/existing-business/agent`

That page is read-only for the current demo.

## 6. Run The Irish Life New Business Journey

Open:

- `https://verifier.test.instech-eudi-poc.com/irish-life/new-business/customer`

For New Business, the easiest rule is simple:

- whatever personal details and address are entered into the Irish Life New Business case must match the PID disclosed from the wallet

To avoid avoidable mismatch during stakeholder demos, reuse the same values as the issued happy-path PID:

1. given name: `Patrick`
2. family name: `Murphy`
3. birth date: `1980-04-12`
4. current address: `1 Main Street, Dublin, Leinster, D02 XY56`

## 7. Demo Tips

- Use the newest `Latest` APK release, not an older install already on the phone.
- Use the cloud `Demo` APK, not a local `Dev` build.
- For Existing Business, only policy number `12345678` is expected to succeed.
- For both Irish Life journeys, matching is driven by the disclosed PID values.
- Address matching uses the structured PID address fields and reconstructs the value in this order: street, locality, region, postal code.

## 8. Suggested Email Text

Use this as a short stakeholder email and keep the markdown file above as the maintainable source of truth.

```text
Subject: EUDI wallet demo instructions

Please use the latest Android demo wallet APK from:
https://github.com/InstechSandbox/eudi-app-android-wallet-ui/releases

After installing the APK, use the public demo environment:

- Issuer: https://issuer.test.instech-eudi-poc.com/
- Irish Life verifier: https://verifier.test.instech-eudi-poc.com/irish-life

When issuing a credential in the wallet, choose:

- PID
- Format: SD-JWT VC
- Country of origin: FormEU

For the happy-path demo, issue a PID with these values:

- Given name: Patrick
- Family name: Murphy
- Birthdate: 1980-04-12
- Country: IE

After entering those identity fields, click Add Optional Attributes, choose Address, and click Add Attributes.

- Street address: 1 Main Street
- Locality: Dublin
- Region: Leinster
- Postal code: D02 XY56

For Existing Business, use policy number 12345678.

If you use New Business, make sure the values entered into the Irish Life form match the wallet PID values exactly.

The fuller tester note is available here:
Stakeholder_Wallet_Demo_Guide.md
```

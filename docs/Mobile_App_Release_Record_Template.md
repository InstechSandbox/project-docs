# Mobile App Release Record Template

Use this template for each redistributed Android APK or iOS TestFlight build.

Keep one completed record per distributed tester build.

---

## Mobile Tester Build Release Record

## Build Identity

- App: `<android-wallet|ios-wallet>`
- Build label: `<release label>`
- Distribution channel: `<APK side-load|GitHub release|TestFlight|other>`
- Build date: `<YYYY-MM-DD>`
- Built by: `InstechSandbox`
- Proof-of-concept only: `yes`

## Source Of Truth

- Source repository: `<repo URL>`
- Branch: `<branch>`
- Commit SHA: `<commit sha>`
- Corresponding source visible to testers: `<yes/link>`

## Modification Record

- Modification summary:
  - `<item>`
  - `<item>`
- Modification date: `<YYYY-MM-DD>`
- Branding changes included: `<yes/no>`
- Functional changes included: `<yes/no>`
- Service rewiring included: `<yes/no>`

## Notices Retained

- Repository `LICENSE.txt` preserved: `<yes>`
- Repository `NOTICE.txt` preserved: `<yes>`
- Existing file-header material preserved in source: `<yes>`
- Additional modification notice published by `InstechSandbox`: `<yes/link>`

## Third-Party Notice Bundle

- Dependency inventory generated: `<yes>`
- Dependency inventory path: `<path or URL>`
- Third-party notice bundle path: `<path or URL>`
- Release-specific reconciliation completed against shipped dependency set: `<yes/no>`

## Distribution Notes

- Intended tester audience: `<small named cohort>`
- Production-ready: `no`
- Official upstream release: `no`
- Tester access notes:
  - `<item>`
  - `<item>`

## Device Compatibility Statement

- Evidence-backed minimum OS statement: `<for Android: Android 10 / API 29 or later; otherwise platform-specific statement>`
- Evidence-backed required hardware statement: `<for Android: camera, Bluetooth, Bluetooth LE; NFC optional; otherwise platform-specific statement>`
- Hardware not proven as minimum: `<RAM|storage|CPU class|specific device family|none>`

## Tested On Declaration

- Required because definitive minimum hardware is proven: `<yes/no>`
- Device type: `<physical device|emulator|both>`
- Device make and model:
  - `<item>`
  - `<item>`
- OS version(s):
  - `<item>`
  - `<item>`
- Build tested: `<variant, version name, version code, or release tag>`
- Flows exercised:
  - `<launch|PIN setup|issuance|same-device presentation|proximity|other>`
  - `<item>`
- Outcome summary: `<passed with noted limitations|passed|failed>`
- Known limitations or gaps:
  - `<item>`
  - `<item>`

## Links

- Compliance bundle: `<path or URL>`
- Project compliance guidance: `project-docs/docs/Mobile_App_Distribution_Compliance.md`
- Dependency inventory baseline: `project-docs/docs/Mobile_Third_Party_Notice_Inventory.md`

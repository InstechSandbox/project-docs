# Mobile Third-Party Notice Inventory

## Purpose

This document records the current dependency-inventory baseline for the Android and iOS wallet forks.

It is not a substitute for a release-specific dependency audit. It is a working inventory that supports proof-of-concept tester distribution until an automated notice-generation pipeline exists.

## How To Use This Inventory

- use it as the baseline list of third-party packages that may require notice handling
- reconcile it against the actual dependency set shipped in the tester build
- keep the repository `LICENSE.txt` and `NOTICE.txt` files in addition to this inventory
- refresh this document when the dependency manifests change materially

## iOS Wallet Baseline Inventory

Source manifest: `eudi-app-ios-wallet-ui/EudiReferenceWallet.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

Current Swift package identities observed in the repo:

- `activityindicatorview`
- `aexml`
- `alerttoast`
- `asn1`
- `av-lib-ios-w3c-dc-api`
- `bigint`
- `bluetoothkit`
- `codescanner`
- `combineexpectations`
- `cryptoswift`
- `cuckoo`
- `digest`
- `eudi-lib-ios-iso18013-data-model`
- `eudi-lib-ios-iso18013-data-transfer`
- `eudi-lib-ios-iso18013-security`
- `eudi-lib-ios-openid4vci-swift`
- `eudi-lib-ios-rqes-csc-swift`
- `eudi-lib-ios-rqes-kit`
- `eudi-lib-ios-rqes-ui`
- `eudi-lib-ios-siop-openid4vp-swift`
- `eudi-lib-ios-statium-swift`
- `eudi-lib-ios-wallet-kit`
- `eudi-lib-ios-wallet-storage`
- `eudi-lib-podofo`
- `eudi-lib-sdjwt-swift`
- `filekit`
- `jose-swift`
- `joseswift`
- `keychainaccess`
- `pathkit`
- `peppermint`
- `phonenumberkit`
- `rainbow`
- `sdwebimage`
- `sdwebimagesvgcoder`
- `sdwebimageswiftui`
- `secp256k1.swift`
- `spectre`
- `stencil`
- `swift-argument-parser`
- `swift-asn1`
- `swift-certificates`
- `swift-collections`
- `swift-crypto`
- `swift-log`
- `swift-syntax`
- `swiftcbor`
- `swiftcopyablemacro`
- `swifthpke`
- `swiftui-shimmer`
- `swiftyjson`
- `swinject`
- `tomlkit`
- `xcodeproj`
- `zlib`

Some of these packages may be used only for build-time, generation, or test support rather than the shipped app runtime. Before distributing a tester build, reconcile this list against the actual archive contents and retain the notices needed by the shipped set.

## Android Wallet Baseline Inventory

Source manifest: `eudi-app-android-wallet-ui/gradle/libs.versions.toml`

The Android catalog mixes runtime libraries with build, plugin, and test dependencies. The runtime-app side most relevant to a distributed APK currently includes the following declared aliases:

- `accompanist-permissions`
- `androidx-activity-compose`
- `androidx-appAuth`
- `androidx-appcompat`
- `androidx-biometric`
- `androidx-browser`
- `androidx-camera-camera2`
- `androidx-camera-core`
- `androidx-camera-lifecycle`
- `androidx-camera-view`
- `androidx-compose-bom`
- `androidx-compose-foundation`
- `androidx-compose-foundation-layout`
- `androidx-compose-material-icons-extended`
- `androidx-compose-material3`
- `androidx-compose-material3-windowSizeClass`
- `androidx-compose-runtime`
- `androidx-compose-runtime-tracing`
- `androidx-compose-ui-tooling-preview`
- `androidx-compose-ui-util`
- `androidx-constraintlayout-compose`
- `androidx-core-ktx`
- `androidx-core-splashscreen`
- `androidx-dataStore-core`
- `androidx-lifecycle-runtimeCompose`
- `androidx-lifecycle-viewModelCompose`
- `androidx-metrics`
- `androidx-navigation-compose`
- `androidx-profileinstaller`
- `androidx-room`
- `androidx-room-ksp`
- `androidx-tracing-ktx`
- `androidx-window-manager`
- `androidx-work-ktx`
- `coil-kt`
- `coil-kt-compose`
- `coil-kt-network-okhttp`
- `coil-kt-svg`
- `compose-cloudy`
- `eudi-wallet-core`
- `google-phonenumber`
- `gson`
- `koin-android`
- `koin-annotations`
- `koin-compose`
- `kotlin-stdlib`
- `kotlinx-coroutines`
- `kotlinx-coroutines-android`
- `kotlinx-coroutines-guava`
- `kotlinx-datetime`
- `kotlinx-serialization-json`
- `ktor-android`
- `ktor-client-content-negotiation`
- `ktor-logging`
- `ktor-okhttp`
- `ktor-serialization-kotlinx-json`
- `material`
- `protobuf-kotlin-lite`
- `rqes-ui-sdk`
- `slf4j`
- `timber`
- `treessence`
- `zxing`

The same catalog also includes declared build, plugin, benchmarking, and test-only aliases such as Gradle plugins, JUnit, Espresso, Robolectric, Mockito, Kover, Sonar, OWASP dependency-check, secrets plugins, and benchmark helpers. Those entries may not need to travel with the shipped APK, but they should not be ignored automatically. The release-specific dependency set should determine the final notice bundle.

## Current Gap

No repo-native automated process was identified in either wallet repo for producing a packaged-app notice bundle.

Until such tooling exists, the safe release posture is:

1. preserve the repo-level `LICENSE.txt` and `NOTICE.txt`
2. use this document as the baseline dependency inventory
3. reconcile the inventory against the actual shipped dependency graph for the tester build
4. publish a release-specific third-party notice bundle with the build record

To reduce manual effort, `project-docs/scripts/generate-mobile-compliance-bundle.sh` now generates a release-sidecar bundle with copied repo notices, extracted dependency inventory, harvested license metadata, generated notice markdown, saved license texts where available, and a prefilled release record. It is still necessary to confirm the final shipped dependency set before distribution.

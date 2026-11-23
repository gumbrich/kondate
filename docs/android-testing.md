# Android testing build

Version **1.0.1 (build 2)**, prepared 2026-11-23 from `codex/android-phone-build-20261123`. Requires Android 7.0 (API 24) or newer; universal APK includes arm64, ARMv7 and x86_64.

## Install on your phone

Download [kondate-1.0.1-android-test.apk](https://github.com/gumbrich/kondate/releases/download/android-test-1.0.1/kondate-1.0.1-android-test.apk) from the [GitHub prerelease](https://github.com/gumbrich/kondate/releases/tag/android-test-1.0.1) on your Android phone, open the download, and allow installation from that browser if Android asks. The launcher calls the app **Kondate**.

This is a release-mode personal testing build, signed with the existing local Android test key, not a Play Store production release. Install it over a compatible existing Kondate installation to keep local data. If Android reports a signature conflict, keep the old app installed and report the message; uninstalling would remove its local data. Mac-local recipes and login sessions do not automatically appear on a new phone installation.

## Try these flows

1. **Wochenplan aus Foto** → take/select a photo → **Handschrift auslesen**. Correct the draft, select days and confirm import. Recognition runs on-device; handwriting can need substantial correction.
2. Open a day and link a saved recipe, or add ingredients manually to the shopping list. Photo-imported meal names alone do not supply ingredients.
3. Shopping list → **Shop-Vorschau** → **Warenkorb vorbereiten**. Choose a specific Coop product for each ingredient and set total packs. Missing choices block continuation.
4. Treat Coop as assisted testing: automatic additions remain unreliable in a known case. Check the actual basket after reload, avoid blindly repeating an uncertain addition, and complete checkout yourself.

## Checks performed

- Flutter analysis clean; 55 app tests, 15 core tests, 2 parser tests and 12 production Coop JavaScript selector checks passed.
- Native seven-day printed-image recognition passed on Mac and an isolated Android API 36.1 arm64 emulator.
- Android device test passed for creating a recipe with a long title, linking Monday, opening its ingredients in shopping preparation, and blocking unresolved Coop choices. Uses isolated preferences and makes no retailer write.
- The exact release APK installed and launched normally through Flutter on the isolated emulator. Its Android signature, version and architecture metadata verified. UI-tool attachment to the emulator was unavailable, so this is launch/log evidence, not a separate visual release-mode acceptance test.
- Fixed two phone-width overflows found by that workflow: recipe dropdown and product-choice button.

Physical phone camera/gallery, Android activity recovery, handwriting quality, backend sync and authenticated Android Coop behavior still need device acceptance. No new Claude review was performed for these layout changes.

## Reproduce

Use Flutter 3.41.5. From `apps/mobile`:

```sh
flutter pub get
flutter analyze
flutter test
node tool/check_coop_selectors.mjs
flutter test integration_test/photo_week_plan_device_test.dart -d DEVICE_ID
flutter test integration_test/phone_flow_device_test.dart -d DEVICE_ID
# Run after device tests/runs have finished, not concurrently:
flutter build apk --release
```

The normal distributable is `build/app/outputs/flutter-apk/app-release.apk`. Never distribute a device integration-test target. Release currently uses the existing local debug signing configuration; production signing is separate future work.

Artifact SHA-256: `a7fc62cb7cd229fa7101c1b30c731dac4085cba7a370005a0e2007c61c2e35dd`.

# Weekly plan from a photo

Kondate can take or choose a photo, read text **on the device**, and turn explicitly recognized German weekdays into an editable draft. It does not generate recipes or ingredients from the image.

## Use it

1. Open **Wochenplan aus Foto** below the weekly plan.
2. Choose **Foto aufnehmen** or **Foto auswählen**. Allow camera access when the operating system asks.
3. Press **Handschrift auslesen**. No account, API key, backend update, or internet connection is required for recognition.
4. Compare the draft with the photo. Zoom the preview and expand **Gesamten erkannten Text anzeigen** to see text that could not be assigned. Correct meals and fill missing days.
5. Check the days to import, then press **… Tage in den Wochenplan übernehmen**. Replacing existing days requires a second confirmation. Back or Cancel leaves the saved plan unchanged.

Only selected, nonblank meal text is saved. Other days, saved recipes, household settings, and shopping preferences remain intact. A changed meal loses its old recipe link so it cannot silently retain that recipe's shopping ingredients. Recipes can subsequently be chosen through the existing day editor and recipe suggestions. Confirmed meal text follows the app's existing household-sync behavior; the photo and raw recognized text are not included in that state.

## Accuracy and privacy

- The first version is an assisted import. It is **not reliable automatic handwriting transcription**. On the supplied slanted handwritten whiteboard, Mac recognition missed several meals and misread words. Manual corrections remain necessary.
- Every OCR-derived entry is marked uncertain and starts unchecked, regardless of the engine's confidence. Missing or duplicate weekday labels are not guessed. Only text on the same row as a recognized weekday is joined; continuation lines remain in the complete recognized text for review.
- Photograph the board straight-on, with good lighting and clear weekday labels (`Mo`–`So` or full German names). Blur, glare, perspective and cursive writing reduce accuracy.
- Image pixels go to Apple Vision on Mac or the bundled ML Kit Latin model on Android. There is no image-upload endpoint or cloud recognizer. The photo picker may keep a temporary local cache file on mobile; Kondate does not put images into saved plans, household sync, logs, or the repository.
- The native engines are platform SDKs, not newly trained or claimed to be open-source models. `LocalWeekPlanRecognizer` and its normalized text-line boundary can be replaced with a stronger on-device/open-source recognizer later. Evaluate it against representative handwriting before changing the default.

## Run and test

Use the repository's tested Flutter version, **3.41.5**. From the repository root:

```sh
cd apps/mobile
flutter pub get
flutter run -d macos
```

For Android, connect the phone, select its ID from `flutter devices`, then run `flutter run -d DEVICE_ID`. The bundled recognition model increases the Android app size but avoids a first-use model download.

Checks from `apps/mobile`:

```sh
flutter analyze
flutter test
node tool/check_coop_selectors.mjs
flutter test integration_test/photo_week_plan_device_test.dart -d macos
flutter build macos --release
flutter build apk --debug
```

The device integration test generates a synthetic seven-day image in memory and exercises the actual native recognizer, normalization and weekday mapping. It does not launch the real home screen or touch saved household data. The same test can be run with an Android device ID. A successful printed-text test does not prove handwriting accuracy.

## Implementation

- `image_picker`: gallery/file selection and Android camera; Android lost-image recovery returns to review after activity recreation.
- Mac: AVFoundation camera sheet, camera permission explanation, sandbox camera and selected-file read entitlements; Vision recognition on a background queue.
- Android: native ML Kit `com.google.mlkit:text-recognition:16.0.1`, with the Latin model bundled at build time.
- Flutter normalizes images to at most 2000 pixels on the longest side, strips metadata by re-encoding pixels as PNG, and limits source files to 20 MB / normalized output to 16 MB.
- iOS has camera/photo-library usage descriptions but no native OCR adapter in this change; other unsupported recognition platforms show a manual-entry fallback.
- No LangGraph, Python service, cloud account, API key, or training pipeline is needed for this flow.

Native references: [Apple Vision text recognition](https://developer.apple.com/documentation/vision/vnrecognizetextrequest), [ML Kit bundled Android text recognition](https://developers.google.com/ml-kit/vision/text-recognition/v2/android), [Flutter image picker](https://pub.dev/packages/image_picker).

## Acceptance record, 2026-11-15

- Verified Mac: camera permission completed by user; a captured image reached review. The supplied local JPEG opened, native text recognition populated an editable draft, and cancelling preserved the existing week plan.
- Verified: Mac device integration test recognized all seven weekdays/meals in a generated printed example.
- Verified: 42 Flutter app tests, clean analysis, 12 existing Coop selector checks, GitHub CI on `4651c80`, and Mac debug/release and Android debug builds. Automated checks cover merging/persistence, stale recipe links, ambiguous rows, missing/duplicate weekdays, camera denial, image normalization, and overwrite confirmation.
- Not yet verified: physical Android camera/recognition, Android activity-death recovery, denied/revoked Mac permissions on a real device, or a complete real-photo plan saved on the user's account. Persistence is covered with isolated test preferences instead.
- Known limitation: difficult handwriting remains inaccurate. Local grayscale, red-channel and perspective experiments did not consistently improve the supplied photo; none was enabled automatically.

Remaining manual checks: Android camera/gallery in airplane mode; cancel each picker; deny/revoke camera access; restore after Android activity destruction; edit uncertain text; select only two days and confirm that the other five remain unchanged after restart.

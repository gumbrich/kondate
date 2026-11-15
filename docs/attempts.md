# Kondate attempts and findings

Preserve unsuccessful approaches here so the next agent does not repeat them. Dates below are observation dates unless specified otherwise. Never include passwords, cookies, tokens, personal addresses, or private basket contents.

## 2026-11-15 photo-to-week-plan

- No camera, photo import, or OCR existed in the app. The existing meal-idea/day model is sufficient; imported text does not need new recipe or household schemas.
- Apple Vision on the supplied handwritten whiteboard missed several weekday/meal lines and misread words. Its high confidence values did not establish correctness. All OCR-derived entries therefore remain unchecked and marked for review.
- Local grayscale/contrast, red-channel and perspective-correction experiments changed the recognized text but did not consistently improve accuracy. Do not automatically enable these transforms based on this one image.
- The user explicitly chose on-device recognition, accepted manual corrections, and allowed open-source recognizers if useful. No photo was sent to Anthropic and no cloud-recognition endpoint was added. Mac uses Apple Vision; Android uses the bundled ML Kit Latin model.
- `image_picker` has no default Mac camera implementation. A small AVFoundation sheet supplies capture; the plugin still handles selected files and Android camera/gallery. Both Mac build configurations need camera and selected-file read entitlements.
- The protected macOS camera permission prompt could not be controlled by the UI tool. User allowed access; a captured image then appeared in review. Do not infer camera denial from that tool restriction.
- Raw Swift Vision execution failed in the restricted process but worked in the normal Mac environment. Native app OCR also succeeded. Photo data stayed local throughout.
- Android initially needed an installed SDK Platform 34; the build completed after Gradle installed it using an already-accepted SDK license. The bundled ML Kit build then passed. No physical Android test has been performed.
- A copied one-pixel PNG test fixture had invalid image data; replaced it with a valid generated PNG containing a synthetic metadata chunk. No private photo is included in tests.
- Native Mac generated-image integration test passed for all seven days. This proves the pipeline, not handwriting quality. Existing real recipes/week plan were preserved; test persistence uses isolated preferences.

## 2026-11-15 Coop baseline

- User recalls Coop ordering did not work previously; exact historical failure is not yet established.
- Git history contains multiple Coop iterations: saved products, WebView tests (`e533bce`), state inspection (`b516272`), auto-run (`ebf7510`), login (`a07fbda`), status/skip (`a7bd729`), credentials (`1d31a72`), and retries (`a580753`). These are implementation milestones, not live verification records.
- `CoopAssistantScreen._runAddInternal` returned success when JavaScript returned `clicked:`. It recorded before/after state but did not compare it. Automatic advancement and retry therefore had no reliable basket confirmation.
- The old first-match `productbasketplus` search was global and could target a recommendation. New controls must be scoped to the product detail container and exact SKU.
- Shopping quantities were discarded when the assistant received saved product links. There was no pack-size conversion. This branch asks for explicit total packs per SKU, including existing basket contents.
- Public website inspection: product 3081654 displayed a quantity of 1 immediately after Add, then reverted. Reload showed the original Add control. Console contained an `autoLogin` JavaScript error. Cause and relation to the user's native Mac session remain unverified; no order was submitted.
- Observed markup: detail container `[data-product-basic-info][data-productid]`, add button `[data-testauto="productbasket"]`, quantity `input[data-product-quantity]` with `name="addtobasket"` and an SKU-suffixed test attribute. The quantity is a pack count; product weight and header basket value are not quantity evidence.
- The Mac release entitlement omitted outbound network access while the debug entitlement included it. Added the client-network entitlement to release builds for backend and Coop access.
- Existing Mac debug credentials fallback uses SharedPreferences rather than secure storage. This is pre-existing; credential-storage hardening is a separate issue. Do not inspect or log stored credentials.

## Review and verification

- `flutter analyze` passed and all 22 app tests passed (14 new service tests). Tests cover persisted increments, repeat targets, existing quantities, optimistic rollback, late success, login loss, unavailable/invalid pages, bridge errors, stale guards and cancellation.
- Debug app launched and the release build passed. The native WebView rendered the product page, cookie controls and Coop/Supercard login form. Authenticated writes remain pending; do not label the retailer integration verified.
- A navigation guard prevents overlapping programmatic loads; navigation controls are disabled while loading and page interaction is disabled during automatic actions. Login loss after dispatch is classified as uncertain so batch retries skip it.
- GitHub connector issue writes returned HTTP 403 (integration permission). Existing authenticated `gh` worked: Coop acceptance [#32](https://github.com/gumbrich/kondate/issues/32), shopping amounts [#33](https://github.com/gumbrich/kondate/issues/33).
- Some displayed shopping quantities looked implausible; root cause is unknown. Track separately rather than deriving pack counts from those amounts.
- `claude auth status` in the restricted environment could not access the existing login; the ordinary Mac environment confirmed sign-in. Do not infer signed-out status from that restricted check.
- Automatic approval review rejected sending the prepared six-source-file plus test-file review bundle to Anthropic without explicit source-transfer approval. User approval is pending; Claude has not reviewed this branch.
- Flutter dependency resolution rewrites unrelated Linux/Windows generated plugin registration files. Exclude that generated churn from this Mac/Coop change.


## Native Mac follow-up

- User completed Coop sign-in inside Kondate. Session survived the assistant's reload.
- First quantity read failed before any click: the narrow WebView layout uses `display: contents` on `[data-product-basic-info]`, giving that container zero client rectangles. The wide public-page layout uses `display: flex`. Visibility now includes visible descendants for `display: contents`; read-only verification returned quantity 0 for SKU 6665497.
- Added a read-only quantity button and debug-only SKU/count/selector diagnostics. These do not log URLs, credentials, account content, cookies or addresses.
- A subsequent single add did not produce a confirmed increment after reload. The assistant stopped as uncertain. Opening Coop's actual basket then displayed a delivery-address confirmation. Cause is not proven; user must resolve that prompt directly before another write.
- Auto-review rejected an earlier retry because it considered unreadable state a duplicate-write risk. A separate read-only check established quantity 0 before the next test. Never bypass an uncertain result by automatically repeating the action.
- GitHub's unpinned stable SDK resolved to Flutter 3.50.0 and failed analysis on Material API deprecations throughout the existing app. CI is now pinned to the locally tested Flutter 3.41.5; a future SDK migration should be a separate change.
- Explicit approval to send the six changed source files and test file to Anthropic was received. Claude's read-only review is running; no report yet.

## Live outcome and completed review

- Login plus user-confirmed delivery address enabled successful automatic additions of yoghurt SKU 6665497 and milk SKU 4389993. Reloaded quantities and actual basket lines showed one pack each. The milk SKU is a 6 × 1 l multipack, not a single bottle.
- Plain porridge SKU 6805933 had a promotion button visibly labelled `(2)`. One click added two, which the service correctly rejected as an unexpected increment. The user explicitly requested reduction to one; a single manual decrement in Coop produced one, then the service verified it after reload. Final actual basket: 1/1/1. No order placed.
- The saved-product editor only offered predefined ingredients, so temporary extra-product links were added to basket preparation. This enabled porridge without changing saved mappings or recipes.
- Multi-pack guards now inspect both button signals and the input step. Never assume one click equals one pack.
- Claude produced two independent read-only reports. The original text-output run was slow; a harmless READY prompt confirmed authentication/API operation. A focused medium-effort review with a direct prompt and streamed output completed. See `docs/claude-review.md` for findings, fixes and remaining hydration uncertainty.
- Final checks: 27 Flutter tests, 12 selector fixture assertions, clean analysis and a successful Mac release build. Three-product UI evidence preceded the final adapter changes; those changes have automated coverage, with final live retest still open.

- Final native retest on implementation commit `f4bb162`: the screen kept open across callback hot reloads timed out safely; reopening the assistant created fresh navigation delegates and all three products verified at one with the document-replacement guard active. No new pack was added. Reopen a WebView screen after changing its initState navigation callbacks. GitHub CI passed on the implementation commit.

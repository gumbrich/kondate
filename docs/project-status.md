# Kondate project status

Updated 2026-11-23. Primary test device: Mac. Android is checked after substantial improvements.

Three known Coop products were confirmed at one pack each in the native Mac basket on 2026-11-15. Yoghurt and milk were added automatically; porridge required an explicitly approved manual correction for a two-pack promotion. Checkout remains manual. A passing unit test does not establish that a live retailer integration works.

## Evidence levels

- **Verified:** name the test, device, date, and exact behavior observed.
- **Implemented but unverified:** code exists; the real user journey still needs a test.
- **Known broken:** reproducible failure or concrete defect; link the issue or evidence.
- **Not implemented:** no supported workflow exists yet.

## Feature status

| Feature | Status and evidence | Next check |
| --- | --- | --- |
| Mac app launch | Verified locally on 2026-11-15 using Flutter 3.41.5; debug launch and release build passed | Updated app launched; pack-target dialog and native Coop product/login pages rendered |
| Shopping calculations | Existing automated tests passed on 2026-11-15 (core package) | Investigate implausible displayed amounts: [#33](https://github.com/gumbrich/kondate/issues/33) |
| Recipe import | Parser and backend fixture tests passed on 2026-11-15 | Live import from the user's trusted sites |
| Recipe search | Implemented but unverified with a live SerpAPI key in this session | Test the deployed backend separately |
| Household sync | Local API tests passed in the LangGraph branch | Two-device conflict and recovery test |
| Coop login | Verified sign-in and reload persistence in native Mac WebView on 2026-11-15 | User completed address confirmation; session survived reloads |
| Coop basket | Main uses click-only success. This branch verified three exact SKU quantities after reload; promotional additions stop for manual handling | Remaining checks in [#32](https://github.com/gumbrich/kondate/issues/32): slow loading and live cancellation |
| Ingredient amounts to pack counts | Not implemented automatically | User explicitly chooses total packs per SKU |
| Coop checkout / order submission | Not implemented as a complete automated flow | Keep manual |
| Android | API 36.1 arm64 emulator: native seven-day OCR and recipe → weekly plan → shopping preparation tests passed on 2026-11-23 | Physical phone camera, activity recovery and authenticated Coop behavior remain unverified |
| LangGraph recipe discovery | Tested and pushed separately as `codex/langgraph-recipe-search`, commit `bee2c3f`; not part of this Coop branch | Optional app feature; not required for coding agents |
| Photo to weekly plan | On-device Mac/Android implementation on `codex/photo-week-plan`; Mac camera/image preview, local OCR and cancellation observed; seven-day native printed-example test passed | Handwriting remains inaccurate; physical Android and activity-recovery acceptance pending; see [photo guide](photo-week-plan.md) |

## Development tools

| Tool or approach | Evidence | Use now |
| --- | --- | --- |
| Codex desktop, local terminal, GitHub | Clone, edits, tests, earlier branch push, and issue creation via `gh` succeeded; connector issue creation returned 403 | Primary implementation workflow |
| Flutter on Mac | Analysis/tests and a debug launch succeeded | Primary app testing |
| Claude Code | Installed (2.1.312), signed in; authenticated status confirmed | Two actual read-only reports received; findings and dispositions in [review record](claude-review.md) |
| Coop in the in-app browser | Public product pages render; an add briefly showed one pack then reverted; a reload did not retain it | Read-only inspection and diagnostics; not proof of native authenticated cart behavior |
| Text-based button guessing | Can match unrelated recommendations and does not prove basket state | Replaced with exact SKU-scoped controls |
| Click result as success | Defect confirmed in source; transient quantity also observed on the live website | Never use as verification |
| LangGraph / LangSmith Studio | LangGraph installed only for the separate backend experiment; Studio not configured | Not needed for the present development workflow |

## Android testing build, 2026-11-23

Task branch: `codex/android-phone-build-20261123`, based on ingredient-selection commit `1eec664`. Version `1.0.1+2`; Android launcher name is now Kondate. Existing package ID and local test signing identity are retained. No data migration or backend change.

- **Verified:** clean Flutter analysis; 55 app tests, 15 core tests, 2 parser tests and 12 production Coop selector checks passed. Native synthetic seven-day recognition passed on both Mac and an isolated Android API 36.1 arm64 emulator. The complete manual-recipe → Monday recipe link → shopping list → Coop preparation workflow also passed on that emulator using isolated preferences and no retailer writes.
- **Build verified:** universal release-mode APK (Android API 24+) built, signature verified, and installed/launched on the isolated emulator. Version/label/package metadata checked. Release visual inspection was unavailable because the UI tool could not attach to the emulator; device integration tests above used debug mode.
- **Fixed:** a long recipe name overflowed the day editor's dropdown, and the product-selection button overflowed the phone-width preparation screen. A new 390 × 844 regression test covers both and proves unresolved ingredients block continuation rather than silently disappearing.
- **Unverified:** physical Android camera/gallery, first use in airplane mode, activity-death recovery, live backend synchronization and Android Coop basket behavior. Printed-example OCR is not evidence of handwriting accuracy. No live basket mutation was attempted this session.
- **Known limitation:** automatic Coop additions are still unreliable in the previously observed feta case; manual completion and persisted-quantity checks remain necessary. A photographed dish name still needs a linked recipe or manually supplied ingredients.

Build/install and repeatable checks: [Android testing](android-testing.md). Historical evidence below remains dated; the previous Claude review does not cover this turn's layout-only changes.

## Previous ingredient branch

Current follow-up: `codex/ingredient-coop-selection` ([draft PR #36](https://github.com/gumbrich/kondate/pull/36)), based on photo commit `d7c1700`. Adds local German/Swiss German/English cooking-word suggestions, live native Coop product selection for arbitrary ingredients, manual shopping items in shop preparation, mandatory resolution of selected missing products, and preservation of custom saved mappings. Fixes rice being classified as eggs and short units/kilograms being lost. Unknown ingredient amounts are labelled explicitly; pack totals remain user-selected.

Verification: 52 Flutter tests and clean analysis; Mac release and Android debug builds; 12 existing Coop selector checks. Native Mac manual ingredient → live Coop search → exact-product choice survived app restart. User-approved Gazi Bio Feta 135 g ended at one pack, confirmed after reload and in the actual basket. Two automatic attempts stopped unconfirmed; zero was checked before further action. A direct native click on Coop Add succeeded, followed by automatic reload verification without duplication. This is a verified final basket with manual assistance, not a successful unattended addition. Claude completed the approved code-only review; reproduced ingredient-identity/unit findings were fixed with regression coverage. Android device acceptance and phone Coop-app synchronization remain unverified. Recipe-name recognition does not produce a complete recipe automatically; the shop preview now lists planned meals without ingredients.

Previous photo branch:

`codex/photo-week-plan`, [draft PR #35](https://github.com/gumbrich/kondate/pull/35), based on `codex/coop-basket-verification` at `ba71d78` to preserve the completed Coop work. This is separate from the LangGraph experiment. The underlying Coop changes are in [draft PR #34](https://github.com/gumbrich/kondate/pull/34).

Photo import adds camera/gallery selection, offline native text recognition, explicit review and day selection, and safe plan merging. All 42 app tests, analysis, and 12 existing Coop selector checks passed. [GitHub CI](https://github.com/gumbrich/kondate/actions/runs/43719135601) passed for implementation commit `4651c80`. No photo upload, backend changes or API keys. Mac debug/release and Android debug builds passed; the Mac native integration test read a generated seven-day example. The supplied handwritten photo required corrections. See the [photo guide](photo-week-plan.md) for exact scope and remaining device checks.

## Previous Coop implementation

Implemented explicit total-pack targets, exact-SKU quantity checks, reload verification, bounded actions, safe stopping, read-only inspection, and temporary extra-product links. Shared logic serves the assistant and single-product screen. Saved recipes and product preferences were preserved.

## Verification (2026-11-15)

- Flutter 3.41.5: analysis clean; 27 app tests passed (16 service, 3 navigation adapter, 8 existing).
- 12 production-JavaScript selector fixture checks passed, including narrow-layout containers and conflicting promotion signals.
- Mac release build passed with outbound network permission. CI is pinned to the same Flutter version; CI passed for implementation commit `f4bb162`.
- Native Mac: login and address confirmed by user; three final SKU counts were 1, 1, 1 after reload and in the basket. Yoghurt repeated without duplication; milk also stayed at 1 during the later three-product run.
- Porridge initially added 2 through Coop's promotion. The assistant stopped as uncertain. User requested reduction to 1; this was done through Coop, then automatically verified after reload. The final guard blocks visible multi-pack additions before clicking.
- Claude reviewed the six implementation files and service tests. Navigation timing, promotion signals, cancellation/back navigation, and fake-test assertions were tightened. The final navigation guard also passed a fresh-screen native Mac retest: all three targets remained at 1, with 3/3 verified.
- Final navigation verification proves a replacement document, but does not establish a server transaction receipt. Slow asynchronous cart hydration remains a follow-up risk; see the review record.
- Android and live cancellation remain untested. Checkout remains manual; no order submitted.

The assistant uses direct Coop sign-in instead of injecting saved credentials. Existing dedicated login/credential screens remain available. No new runtime dependency was added; the existing WebView platform interface is now explicitly declared for tests.

See [attempts](attempts.md), [development workflow](development-workflow.md), [Coop acceptance](coop-acceptance.md), and [Claude review](claude-review.md).

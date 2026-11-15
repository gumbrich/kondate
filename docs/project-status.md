# Kondate project status

Updated 2026-11-15. Primary test device: Mac. Android is checked after substantial improvements.

The next milestone is three known Coop products at explicit pack quantities, confirmed in the basket. Checkout remains manual. A passing unit test does not establish that a live retailer integration works.

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
| Coop login | Verified sign-in and reload persistence in native Mac WebView on 2026-11-15 | Delivery-address confirmation currently requires user input |
| Coop basket | Known broken in main: click alone marks success. Replacement on this branch requires persisted SKU quantity and stops on ambiguity | Three-product Mac acceptance [#32](https://github.com/gumbrich/kondate/issues/32); not yet passed |
| Ingredient amounts to pack counts | Not implemented automatically | User explicitly chooses total packs per SKU |
| Coop checkout / order submission | Not implemented as a complete automated flow | Keep manual |
| Android | Not tested in this session | Regression check after Mac acceptance |
| LangGraph recipe discovery | Tested and pushed separately as `codex/langgraph-recipe-search`, commit `bee2c3f`; not part of this Coop branch | Optional app feature; not required for coding agents |

## Development tools

| Tool or approach | Evidence | Use now |
| --- | --- | --- |
| Codex desktop, local terminal, GitHub | Clone, edits, tests, earlier branch push, and issue creation via `gh` succeeded; connector issue creation returned 403 | Primary implementation workflow |
| Flutter on Mac | Analysis/tests and a debug launch succeeded | Primary app testing |
| Claude Code | Installed (2.1.312), signed in; authenticated status confirmed | Explicit code-transfer approval received; read-only review running, report pending |
| Coop in the in-app browser | Public product pages render; an add briefly showed one pack then reverted; a reload did not retain it | Read-only inspection and diagnostics; not proof of native authenticated cart behavior |
| Text-based button guessing | Can match unrelated recommendations and does not prove basket state | Replaced with exact SKU-scoped controls |
| Click result as success | Defect confirmed in source; transient quantity also observed on the live website | Never use as verification |
| LangGraph / LangSmith Studio | LangGraph installed only for the separate backend experiment; Studio not configured | Not needed for the present development workflow |

## Active work

Branch: `codex/coop-basket-verification`, based on `main` independently of the LangGraph experiment.

- Add pack targets and verify the exact product quantity after reloading.
- Stop on unreadable state, login, wrong product, unexpected quantity, or cancellation.
- Use the same implementation in the assistant and single-product screen.
- Record test results and Claude review here and in the pull request.

See [attempts](attempts.md), [development workflow](development-workflow.md), and [Coop acceptance test](coop-acceptance.md).

## Branch verification (2026-11-15)

- `flutter analyze`: clean.
- `flutter test`: 22 passed (14 basket-service tests plus 8 existing app tests).
- `flutter build macos --release`: passed; release network-client entitlement included.
- Native Mac UI: meal plan and shopping list preserved, missing mappings disclosed, explicit pack targets shown, Coop product page and sign-in form loaded.
- One authenticated add attempt did not persist; assistant stopped as uncertain. Actual basket requested delivery-address confirmation. Successful writes, repeat-run behavior and Android remain unverified. No order submitted.
- The assistant now uses direct Coop sign-in instead of injecting saved credentials. Existing dedicated login/credential screens remain available.
- Claude review is running after explicit approval. [PR #34](https://github.com/gumbrich/kondate/pull/34) remains draft until review and live acceptance are resolved. CI is pinned to Flutter 3.41.5 after the unpinned newer SDK failed existing Material imports.

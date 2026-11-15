# Kondate project status

Updated 2026-11-15. Primary test device: Mac. Android is checked after substantial improvements.

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
| Android | Not tested in this session | Regression check after Mac acceptance |
| LangGraph recipe discovery | Tested and pushed separately as `codex/langgraph-recipe-search`, commit `bee2c3f`; not part of this Coop branch | Optional app feature; not required for coding agents |

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

## Current branch

`codex/coop-basket-verification`, based on main independently of LangGraph. [Draft PR #34](https://github.com/gumbrich/kondate/pull/34).

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

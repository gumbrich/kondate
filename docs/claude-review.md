# Claude review record

2026-11-15, Claude Code 2.1.312 (reported model `claude-fable-5-1`). User explicitly approved sending six Coop implementation files and their service test to Anthropic. Tools were disabled; the bundle contained code only. Two real read-only reports were received. No credentials, cookies, account details, addresses or household data were included.

## Findings and disposition

- **Reload can finish on a stale navigation callback:** fixed. Both screens forward page-start events, completion requires an armed start, and reload must observe a new document rather than the marker installed in the old document. Three adapter tests cover stale events, document replacement and failure recovery. Navigation failures surface promptly.
- **Multi-pack Add/Plus signals can disagree:** fixed conservatively. Any non-unit signal in the chosen button attribute, visible count label or input step blocks automatic clicking. Twelve JavaScript fixture checks exercise production helpers, including narrow `display: contents` and conflicting promotion signals. Manual handling is required for those buttons.
- **Leaving during a write hides its result:** back navigation is blocked during the bounded action. The assistant retains its Stop control. Cancellation before dispatch is retryable and no longer warns that a write may have occurred.
- **Fake guard assertion could be swallowed by service error handling:** fake records violations and teardown asserts them outside the service catch.
- **Load failure resets verified/manual/skipped status:** preserved existing item status; load errors remain visible.
- **WKWebView redirect cancellation is treated as load failure:** delegates ignore native error -999. The installed WebView error enum has no `cancelled` member.
- **Retry on the basket/login page reads the wrong page:** assistant checks the current SKU and reopens its intended product before running. Wrong-SKU writes remain blocked.
- **Several ingredients share one SKU:** dialog explicitly discloses the merge and asks for a total. It does not infer package counts from ingredient occurrences or weights.

## Remaining uncertainty

The first report raised a conditional risk: if Coop displays an unhydrated Add button for more than the two-sample settling window, zero could be read before the real cart count arrives. The live repeated-target tests did not reproduce this, and a header basket value cannot establish an individual SKU count. The new-document guard fixes the concrete stale-callback case, but does not prove server hydration. Keep the PR draft pending a slow-loading native test and a reliable retailer readiness signal or basket cross-check. Do not describe this as guaranteed transactional or unattended ordering.

The final fixes passed local analysis, 27 Flutter tests, 12 selector checks, a Mac release build, GitHub CI, and a fresh-screen native Mac three-target verification. They were not represented as a fresh Claude approval of the final commit. Review source bundles and full CLI output remain local temporary files; this record preserves the actionable findings without personal data.

## Photo-to-week-plan review, 2026-11-15

Claude Code reported model `claude-fable-5-1`. The user separately approved a code-only review of the photo feature: eight source/test files plus integration changes. No private photo, recognized meal text, or household state was included. Tools were disabled. The first medium-effort request encountered an API retry and produced no report before it was interrupted. A shorter low-effort review of the implementation and integration diff completed and returned two actionable findings:

- **P1, normalized photo size:** a 4 MB PNG limit could reject detailed camera images even after resizing to 2000 pixels. Fixed by allowing 16 MB of normalized PNG data consistently in Flutter and both native bridges, while retaining the 2000-pixel bound and 20 MB source-file limit. A regression test generates a detailed image larger than 4 MB and verifies successful normalization. No cloud-upload constraint is needed for local processing.
- **P2, OCR rectangles near image edges:** rejecting any coordinate outside 0–1 could discard otherwise useful recognition. The shared native-result parser now clips finite rectangles to the image bounds. A regression test preserves a weekday/meal with small edge overshoots; invalid nonfinite geometry is still rejected.

Claude reported no other actionable findings in that focused review. After the fixes, all 42 app tests, analysis, the native Mac seven-day test, Mac release build, and Android debug build passed. This is not a second Claude approval of the corrected commit. The photo remains on-device, and difficult handwriting still needs manual correction.

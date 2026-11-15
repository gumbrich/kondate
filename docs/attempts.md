# Kondate attempts and findings

Preserve unsuccessful approaches here so the next agent does not repeat them. Dates below are observation dates unless specified otherwise. Never include passwords, cookies, tokens, personal addresses, or private basket contents.

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


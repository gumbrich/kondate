# Coop basket acceptance test

Target: macOS first. This milestone prepares a basket; it does not submit an order or payment.

## Preconditions

- Run the current task branch with `flutter run -d macos` from `apps/mobile/`.
- Use three known grocery products with valid saved Coop URLs ending in `/p/<numeric SKU>`.
- Sign in directly on Coop inside Kondate. A browser login elsewhere may not share the native WebView's session.
- Record each starting pack count and choose target totals. Use a mix such as 1, 2, and 3 packs only if these are the user's intended quantities. The target includes packs already in the basket.
- Ingredient amounts (grams/litres) do not automatically determine package counts yet. Confirm the correct pack size on Coop.

## Test

1. Open shopping list → shop preview → prepare Coop basket → assistant.
2. Check that missing product mappings are disclosed and each SKU has a single explicit target.
3. Run one product first. Only mark verified when the exact SKU count survives a reload.
4. Run the other two. Inspect the actual Coop basket and confirm all three SKU counts.
5. Repeat the same target. Counts must not increase again.
6. Test a blocked case (signed out, unavailable product, unreadable page, or interrupted load). The assistant must stop and must not label a click as success.
7. Stop during an action. No subsequent action/product may start. Check any already-dispatched action manually.
8. Confirm a manually checked item is labelled separately from automatic verification.

Do not delete existing basket items to create a test fixture. If the basket already contains more than the target, the assistant stops for manual review rather than removing goods.

## Result record

Date: 2026-11-15

Device: Mac (macOS 15.6); Android follow-up pending.

Tracking: [GitHub issue #32](https://github.com/gumbrich/kondate/issues/32).

Native three-product result: **Pending sign-in and user-selected products/quantities**. Automated state-machine tests and public-page inspection are not substitutes for this test.

Pack-target dialog, missing-link warning, product page and sign-in form rendered in the updated Mac app. No authenticated basket action was performed.

Record only SKU, desired count, observed count, and pass/fail. Do not commit account identifiers, cookies, delivery details, or credentials.

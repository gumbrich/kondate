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

Date: 2026-11-15. Device: Mac (macOS 15.6). Tracking: [#32](https://github.com/gumbrich/kondate/issues/32).

| SKU | Product | Initial | Target | Final after reload / actual basket | Method |
| --- | --- | --- | --- | --- | --- |
| 6665497 | Naturaplan Joghurt Natur 500 g | 0 | 1 | 1 / 1 | Automatic after login/address setup; repeated target stayed 1 |
| 4389993 | Naturaplan Milch Drink UHT 6 × 1 l | 0 | 1 multipack | 1 / 1 | Automatic; later run stayed 1 |
| 6805933 | Naturaplan Porridge Nature 400 g | 0 | 1 | 1 / 1 | Promotion added 2; assistant stopped; user approved manual reduction to 1; automatic reload verification passed |

The assistant displayed 3/3 verified quantities. This is not a fully unattended three-product success: the porridge correction and login/address steps were manual. The final promotion guard now blocks non-unit or conflicting increments. The pack-target dialog, missing-link warning, temporary extra-product flow, actual basket and repeat-target behavior were exercised. No saved recipe/preference edits and no checkout/order submission.

Final code checks: 27 Flutter tests and 12 selector fixture assertions passed; analysis clean; Mac release build passed. Navigation race protections added after the live test have automated coverage; a final native retest, slow-network hydration test, live cancellation and Android follow-up remain open.

Record only SKU/count evidence; never commit account identifiers, cookies, delivery details, or credentials.

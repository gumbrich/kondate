import 'package:core/core.dart';

import 'app_state.dart';
import 'coop_user_preferences.dart';
import 'purchasable_item.dart';
import 'purchasable_item_mapper.dart';

/// The shop receives outstanding recipe ingredients AND manual shopping items.
/// Amounts are ingredient quantities, never inferred retailer pack counts.
List<PurchasableItem> buildShoppingPurchases(
  KondateAppState state, {
  Map<String, CoopUserPreferenceOverride> overrides = const {},
}) {
  final generated = IngredientAggregator.fromRecipes(
    state.selectedMealPlanRecipes(),
    targetServings: state.targetServings,
  );
  final excluded = {
    ...state.shoppingState.removedGeneratedItemIds,
    ...state.shoppingState.checkedGeneratedItemIds,
  };
  final items = <PurchasableItem>[];
  for (final item in generated.items) {
    final quantity = item.quantity;
    final id =
        '${item.name}_${quantity == null ? 'noqty' : '${quantity.value}_${quantity.unit}'}';
    if (excluded.contains(id)) continue;
    items.add(
      PurchasableItemMapper.fromIngredient(
        name: item.name,
        quantity: quantity?.value ?? 1,
        unit: quantity == null ? '' : UnitFormatDe.short(quantity.unit),
        amountDescription: quantity == null ? 'Menge offen' : null,
        userOverrides: overrides,
      ),
    );
  }
  for (final item in state.shoppingState.manualItems.where(
    (item) => !item.checked,
  )) {
    final quantity = QuantityParserDe.parseLeadingQuantity(item.name);
    var name = item.name;
    if (quantity != null) {
      name = name
          .replaceFirst(
            RegExp(r'^\s*\d+(?:[.,]\d+)?(?:\s*-\s*\d+(?:[.,]\d+)?)?\s+\S+\s*'),
            '',
          )
          .trim();
      if (name.isEmpty) name = item.name;
    }
    items.add(
      PurchasableItemMapper.fromIngredient(
        name: name,
        quantity: quantity?.value ?? 1,
        unit: quantity == null ? '' : UnitFormatDe.short(quantity.unit),
        amountDescription: quantity == null
            ? 'Menge offen · manueller Eintrag'
            : item.name.trim(),
        userOverrides: overrides,
      ),
    );
  }
  return items;
}

/// Meal ideas without a recipe must not look like a complete shopping list.
List<WeekdayDe> mealsMissingIngredients(KondateAppState state) => state
    .mealPlan
    .entries
    .where(
      (entry) =>
          (entry.dishIdea?.trim().isNotEmpty ?? false) &&
          (entry.recipeId == null ||
              state.findRecipeById(entry.recipeId!)?.ingredients.isNotEmpty !=
                  true),
    )
    .map((entry) => entry.weekday)
    .toList();

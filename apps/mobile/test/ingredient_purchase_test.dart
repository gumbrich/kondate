import 'package:core/core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app_state.dart';
import 'package:mobile/ingredient_formatter.dart';
import 'package:mobile/meal_spelling.dart';
import 'package:mobile/shopping_purchase_plan.dart';

void main() {
  test('nearby cooking words stay local and preserve separators', () {
    expect(
      MealSpelling.suggestions('Zitronenrisatho'),
      contains('Zitronenrisotto'),
    );
    expect(MealSpelling.suggestions('Wirz-Feta-Härdöpfel-Auflauf'), isEmpty);
    expect(
      MealSpelling.suggestions('leomn rice + Härdöpfle'),
      contains('lemon rice + Härdöpfel'),
    );
    expect(MealSpelling.suggestions('xyzabcdef'), isEmpty);
    expect(
      MealSpelling.suggestions('Shakshouak', knownPhrases: ['Shakshouka']),
      contains('Shakshouka'),
    );
  });

  test('rice is not eggs and short units survive repeated parsing', () {
    expect(IngredientFormatter.canonicalMergeName('Reis'), 'reis');
    expect(IngredientFormatter.canonicalMergeName('Eier'), 'ei');
    for (final unit in ['g', 'kg', 'ml', 'l', 'EL', 'TL']) {
      final parsed = IngredientParser.parse('Feta', 2, unit);
      expect(parsed.unit, unit);
      expect(parsed.displayQuantity, 2);
    }
    expect(IngredientParser.parse('Feta', 2, 'kilogram').unit, 'kg');
  });

  test('manual items, ranges and unknown amounts reach product selection', () {
    var state = KondateAppState.initial()
        .addManualShoppingItem('200 g Feta')
        .addManualShoppingItem('2-3 kg Kartoffeln')
        .addManualShoppingItem('Wirz');
    final items = buildShoppingPurchases(state);
    expect(items.length, 3);
    expect(items.first.displayName, 'Feta');
    expect(items.first.quantity, 200);
    expect(items.first.unit, 'g');
    expect(items[1].amountDescription, '2-3 kg Kartoffeln');
    expect(items.last.amountDescription, contains('Menge offen'));
    state = state.toggleManualShoppingItem(
      state.shoppingState.manualItems.first.id,
    );
    expect(buildShoppingPurchases(state).length, lessThan(3));
  });

  test(
    'recipe occurrences scale; checked and removed ingredients are excluded',
    () {
      final recipe = Recipe(
        id: 'test',
        title: 'Test',
        sourceUrl: Uri.parse('https://example.com'),
        defaultServings: 2.5,
        ingredients: const [
          IngredientLine(
            raw: '200 g Reis',
            normalizedName: 'Reis',
            quantity: Quantity(200, Unit.gram),
          ),
        ],
      );
      var state = KondateAppState.initial()
          .addRecipe(recipe)
          .updateMealPlanEntry(
            weekday: WeekdayDe.montag,
            dishIdea: 'Test',
            recipeId: recipe.id,
          )
          .updateMealPlanEntry(
            weekday: WeekdayDe.dienstag,
            dishIdea: 'Test',
            recipeId: recipe.id,
          );
      expect(buildShoppingPurchases(state).single.quantity, 400);
      final item = IngredientAggregator.fromRecipes(
        state.selectedMealPlanRecipes(),
        targetServings: state.targetServings,
      ).items.single;
      final id = '${item.name}_${item.quantity!.value}_${item.quantity!.unit}';
      expect(
        buildShoppingPurchases(state.toggleGeneratedShoppingChecked(id)),
        isEmpty,
      );
      expect(
        buildShoppingPurchases(state.toggleGeneratedShoppingRemoved(id)),
        isEmpty,
      );
      state = state.updateMealPlanEntry(
        weekday: WeekdayDe.mittwoch,
        dishIdea: 'Meal without recipe',
        recipeId: null,
      );
      expect(mealsMissingIngredients(state), [WeekdayDe.mittwoch]);
    },
  );
}

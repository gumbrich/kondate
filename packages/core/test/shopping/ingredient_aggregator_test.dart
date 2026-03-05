import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  test('aggregates and scales quantities to 2.5 servings', () {
    final r1 = Recipe(
      id: 'r1',
      title: 'A',
      sourceUrl: Uri.parse('https://example.com/a'),
      defaultServings: 4,
      ingredients: const [
        IngredientLine(
          raw: '1,5 EL Olivenöl',
          quantity: Quantity(1.5, Unit.tablespoon),
        ),
        IngredientLine(
          raw: '2 Dosen Tomaten',
          quantity: Quantity(2, Unit.can),
        ),
      ],
    );

    final r2 = Recipe(
      id: 'r2',
      title: 'B',
      sourceUrl: Uri.parse('https://example.com/b'),
      defaultServings: 2,
      ingredients: const [
        IngredientLine(
          raw: '1 EL Olivenöl',
          quantity: Quantity(1, Unit.tablespoon),
        ),
        IngredientLine(
          raw: 'Salz nach Geschmack',
          quantity: null,
        ),
      ],
    );

    final list = IngredientAggregator.fromRecipes([r1, r2], targetServings: 2.5);

    // Olivenöl base volume = ml (1 EL = 15 ml)
    // total = 2.1875 EL -> 32.8125 ml
    final oil = list.items.firstWhere((i) => i.name.contains('olivenöl'));
    expect(oil.quantity, isNotNull);
    expect(oil.quantity!.dimension, UnitDimension.volume);
    expect(oil.quantity!.toBaseValue(), closeTo(32.8125, 1e-9));

    // Tomaten: 2 Dosen * 0.625 = 1.25 (count)
    final tom = list.items.firstWhere((i) => i.name.contains('tomaten'));
    expect(tom.quantity, isNotNull);
    expect(tom.quantity!.dimension, UnitDimension.count);
    expect(tom.quantity!.toBaseValue(), closeTo(1.25, 1e-9));

    final salt = list.items.firstWhere((i) => i.name.contains('salz'));
    expect(salt.quantity, isNull);
  });
}

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
        IngredientLine(raw: '1,5 EL Olivenöl', quantity: Quantity(1.5, Unit.tablespoon)),
        IngredientLine(raw: '2 Dosen Tomaten', quantity: Quantity(2, Unit.can)),
      ],
    );

    final r2 = Recipe(
      id: 'r2',
      title: 'B',
      sourceUrl: Uri.parse('https://example.com/b'),
      defaultServings: 2,
      ingredients: const [
        IngredientLine(raw: '1 EL Olivenöl', quantity: Quantity(1, Unit.tablespoon)),
        IngredientLine(raw: 'Salz nach Geschmack', quantity: null),
      ],
    );

    final list = IngredientAggregator.fromRecipes([r1, r2], targetServings: 2.5);

    // scale factors: r1 => 2.5/4 = 0.625 ; r2 => 2.5/2 = 1.25
    // Olivenöl: 1.5*0.625 + 1*1.25 = 0.9375 + 1.25 = 2.1875 EL
    final oil = list.items.firstWhere((i) => i.name.contains('olivenöl') && i.unit == Unit.tablespoon);
    expect(oil.quantity, isNotNull);
    expect(oil.quantity!.value, closeTo(2.1875, 1e-9));

    final tom = list.items.firstWhere((i) => i.name.contains('tomaten') && i.unit == Unit.can);
    expect(tom.quantity!.value, closeTo(1.25, 1e-9)); // 2 * 0.625

    final salt = list.items.firstWhere((i) => i.name.contains('salz'));
    expect(salt.quantity, isNull);
  });
}

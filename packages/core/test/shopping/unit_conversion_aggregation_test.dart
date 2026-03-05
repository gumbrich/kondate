import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  test('merges mass units (g + kg)', () {
    final r = Recipe(
      id: 'r',
      title: 'R',
      sourceUrl: Uri.parse('https://example.com'),
      defaultServings: 1,
      ingredients: const [
        IngredientLine(raw: '250 g Mehl', quantity: Quantity(250, Unit.gram)),
        IngredientLine(raw: '0,5 kg Mehl', quantity: Quantity(0.5, Unit.kilogram)),
      ],
    );

    final list = IngredientAggregator.fromRecipes([r], targetServings: 1);

    final item = list.items.firstWhere((i) => i.name.contains('mehl'));
    expect(item.quantity, isNotNull);

    // preferred display might be g or kg depending on your threshold.
    // With threshold 1000g, 750g should be displayed as grams:
    expect(item.quantity!.unit, Unit.gram);
    expect(item.quantity!.value, closeTo(750, 1e-9));
  });

  test('merges volume units (EL + ml)', () {
    final r = Recipe(
      id: 'r',
      title: 'R',
      sourceUrl: Uri.parse('https://example.com'),
      defaultServings: 1,
      ingredients: const [
        IngredientLine(raw: '1 EL Öl', quantity: Quantity(1, Unit.tablespoon)),
        IngredientLine(raw: '15 ml Öl', quantity: Quantity(15, Unit.milliliter)),
      ],
    );

    final list = IngredientAggregator.fromRecipes([r], targetServings: 1);
    final item = list.items.firstWhere((i) => i.name.contains('öl'));
    expect(item.quantity, isNotNull);

    // base is ml; preferred display <=1000 => ml, so 30 ml
    expect(item.quantity!.unit, Unit.milliliter);
    expect(item.quantity!.value, closeTo(30, 1e-9));
  });
}

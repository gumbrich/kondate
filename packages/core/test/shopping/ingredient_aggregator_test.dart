import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  test('aggregates and scales quantities to 2.5 servings', () {
    final Recipe r1 = Recipe(
      id: 'r1',
      title: 'A',
      sourceUrl: Uri.parse('https://example.com/a'),
      defaultServings: 4,
      ingredients: const <IngredientLine>[
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

    final Recipe r2 = Recipe(
      id: 'r2',
      title: 'B',
      sourceUrl: Uri.parse('https://example.com/b'),
      defaultServings: 2,
      ingredients: const <IngredientLine>[
        IngredientLine(
          raw: '1 EL Olivenoel',
          quantity: Quantity(1, Unit.tablespoon),
        ),
        IngredientLine(
          raw: 'Salz nach Geschmack',
          quantity: null,
        ),
      ],
    );

    final ShoppingList list = IngredientAggregator.fromRecipes(
      <Recipe>[r1, r2],
      targetServings: 2.5,
    );

    final ShoppingListItem oil =
        list.items.firstWhere((ShoppingListItem i) => i.name == 'olivenöl');
    expect(oil.quantity, isNotNull);
    expect(oil.quantity!.dimension, UnitDimension.volume);
    expect(oil.quantity!.toBaseValue(), closeTo(32.8125, 1e-9));
    expect(oil.displayName, 'Olivenöl');

    final ShoppingListItem tom =
        list.items.firstWhere((ShoppingListItem i) => i.name == 'tomate');
    expect(tom.quantity, isNotNull);
    expect(tom.quantity!.dimension, UnitDimension.count);
    expect(tom.quantity!.toBaseValue(), closeTo(1.25, 1e-9));
    expect(tom.displayName, 'Tomate');

    final ShoppingListItem salt =
        list.items.firstWhere((ShoppingListItem i) => i.name.contains('salz'));
    expect(salt.quantity, isNull);
    expect(salt.displayName, 'Salz nach geschmack');
  });

  test('merges plural and singular ingredient names', () {
    final Recipe r = Recipe(
      id: 'r',
      title: 'C',
      sourceUrl: Uri.parse('https://example.com/c'),
      defaultServings: 1,
      ingredients: const <IngredientLine>[
        IngredientLine(
          raw: '1 Zwiebel',
          quantity: Quantity(1, Unit.piece),
        ),
        IngredientLine(
          raw: '2 Zwiebeln',
          quantity: Quantity(2, Unit.piece),
        ),
      ],
    );

    final ShoppingList list = IngredientAggregator.fromRecipes(
      <Recipe>[r],
      targetServings: 1,
    );

    final ShoppingListItem onion =
        list.items.firstWhere((ShoppingListItem i) => i.name == 'zwiebel');

    expect(onion.quantity, isNotNull);
    expect(onion.quantity!.dimension, UnitDimension.count);
    expect(onion.quantity!.toBaseValue(), closeTo(3, 1e-9));
    expect(onion.displayName, 'Zwiebel');
  });
}

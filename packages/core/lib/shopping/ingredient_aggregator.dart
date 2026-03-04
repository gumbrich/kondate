import '../models/recipe.dart';
import '../units/quantity.dart';
import '../units/unit.dart';
import 'ingredient_name_normalizer_de.dart';
import 'shopping_list.dart';
import 'shopping_list_item.dart';

class IngredientAggregator {
  /// Aggregates ingredients from recipes into a shopping list.
  /// Quantities are scaled to the desired number of servings.
  static ShoppingList fromRecipes(
    List<Recipe> recipes, {
    required double targetServings,
  }) {
    final Map<String, _Accumulator> acc = {};

    for (final recipe in recipes) {
      final factor = _scaleFactor(recipe.defaultServings, targetServings);

      for (final line in recipe.ingredients) {
        final normalized = line.normalizedName?.trim();
        final name = (normalized?.isNotEmpty ?? false)
            ? normalized!
            : IngredientNameNormalizerDe.normalize(line.raw);

        final q = line.quantity?.scale(factor);

        final unit = q?.unit ?? Unit.unknown;
        final key = '${name}__${unit.name}__${q == null ? "noqty" : "qty"}';

        final a = acc.putIfAbsent(
          key,
          () => _Accumulator(
            name: name,
            unit: unit,
            quantity: null,
            hasQuantity: q != null,
          ),
        );

        if (q == null) {
          continue;
        }

        if (a.quantity == null) {
          a.quantity = q;
        } else {
          a.quantity = Quantity(
            a.quantity!.value + q.value,
            q.unit,
          );
        }
      }
    }

    final items = acc.values.map((a) {
      return ShoppingListItem(
        name: a.name,
        quantity: a.hasQuantity ? a.quantity : null,
        unit: a.unit,
      );
    }).toList();

    items.sort((x, y) {
      final c = x.name.compareTo(y.name);
      if (c != 0) return c;
      return x.unit.name.compareTo(y.unit.name);
    });

    return ShoppingList(items: items);
  }

  static double _scaleFactor(double? defaultServings, double targetServings) {
    if (defaultServings == null || defaultServings <= 0) {
      return 1.0;
    }
    return targetServings / defaultServings;
  }
}

class _Accumulator {
  final String name;
  final Unit unit;
  Quantity? quantity;
  final bool hasQuantity;

  _Accumulator({
    required this.name,
    required this.unit,
    required this.quantity,
    required this.hasQuantity,
  });
}

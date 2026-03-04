import '../models/recipe.dart';
import '../units/quantity.dart';
import '../units/unit.dart';
import 'ingredient_name_normalizer_de.dart';
import 'shopping_list.dart';
import 'shopping_list_item.dart';

class IngredientAggregator {
  /// Aggregates ingredients from recipes into a ShoppingList.
  /// targetServings: e.g. 2.5 for your household.
  static ShoppingList fromRecipes(
    List<Recipe> recipes, {
    required double targetServings,
  }) {
    final Map<String, _Accumulator> acc = {};

    for (final recipe in recipes) {
      final factor = _scaleFactor(recipe.defaultServings, targetServings);

      for (final line in recipe.ingredients) {
        final name = (line.normalizedName?.trim().isNotEmpty ?? false)
            ? line.normalizedName!.trim()
            : IngredientNameNormalizerDe.normalize(line.raw);

        final q = line.quantity == null ? null : line.quantity!.scale(factor);

        // Key merges by name + unit + (quantity present?)
        final unit = q?.unit ?? Unit.unknown;
        final key = '${name}__${unit.name}__${q == null ? "noqty" : "qty"}';

        final a = acc.putIfAbsent(
          key,
          () => _Accumulator(name: name, unit: unit, quantity: null, hasQuantity: q != null),
        );

        if (q == null) {
          // We don't sum unknown quantities.
          continue;
        }

        // Sum same-unit quantities
        a.quantity = a.quantity == null
            ? q
            : Quantity(a.quantity!.value + q.value, q.unit);
      }
    }

    final items = acc.values.map((a) {
      final displayName = a.name; // already normalized; later: keep original casing
      return ShoppingListItem(
        name: displayName,
        quantity: a.hasQuantity ? a.quantity : null,
        unit: a.unit,
      );
    }).toList();

    // Stable-ish ordering: by name then unit
    items.sort((x, y) {
      final c = x.name.compareTo(y.name);
      if (c != 0) return c;
      return x.unit.name.compareTo(y.unit.name);
    });

    return ShoppingList(items: items);
  }

  static double _scaleFactor(double? defaultServings, double targetServings) {
    if (defaultServings == null || defaultServings <= 0) return 1.0;
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

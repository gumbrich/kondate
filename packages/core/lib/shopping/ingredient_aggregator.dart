import '../models/recipe.dart';
import '../units/quantity.dart';
import '../units/unit.dart';
import '../units/unit_conversion.dart';
import '../units/unit_dimension.dart';
import 'category_classifier_de.dart';
import 'ingredient_name_normalizer_de.dart';
import 'shopping_list.dart';
import 'shopping_list_item.dart';

class IngredientAggregator {
  /// Aggregates ingredients from recipes into a shopping list.
  ///
  /// Rules (MVP):
  /// - Quantities are scaled to targetServings based on recipe.defaultServings.
  /// - Ingredients are merged by normalized name + unit-dimension (mass/volume/count).
  /// - Mass merges across g/kg, volume merges across ml/l/EL/TL, count merges across count-like units.
  /// - Unknown units are not converted; they are summed only within the same unit.
  /// - If quantity is null, we keep an item with no quantity (not summed).
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

        final scaled = line.quantity?.scale(factor);

        // No quantity: keep separate "noqty" bucket.
        if (scaled == null) {
          final key = '${name}__noqty';
          acc.putIfAbsent(key, () => _Accumulator.noQuantity(name));
          continue;
        }

        final dim = UnitConversion.dimension(scaled.unit);

        // Unknown units: do not cross-convert; keep per-unit bucket.
        if (dim == UnitDimension.unknown) {
          final key = '${name}__unknown__${scaled.unit.name}';
          final a = acc.putIfAbsent(
            key,
            () => _Accumulator.unknownUnit(name, scaled.unit),
          );
          a.unknownSum = (a.unknownSum ?? 0) + scaled.value;
          continue;
        }

        // Known dimension: convert to base and sum in base units.
        final baseValue = UnitConversion.toBase(scaled.value, scaled.unit);
        final key = '${name}__${dim.name}';

        final a = acc.putIfAbsent(key, () => _Accumulator.base(name, dim));
        a.baseSum += baseValue;
      }
    }

    final items = <ShoppingListItem>[];

    for (final a in acc.values) {
      // Category is based on normalized name (German MVP).
      final category = CategoryClassifierDe.classify(a.name);

      if (a.hasNoQuantity) {
        items.add(
          ShoppingListItem(
            name: a.name,
            quantity: null,
            unit: Unit.unknown,
            category: category,
          ),
        );
        continue;
      }

      if (a.dim == UnitDimension.unknown) {
        // Sum stays in the original unknown unit.
        final u = a.unknownUnit ?? Unit.unknown;
        items.add(
          ShoppingListItem(
            name: a.name,
            quantity: Quantity(a.unknownSum ?? 0, u),
            unit: u,
            category: category,
          ),
        );
        continue;
      }

      // Convert base sum to a preferred display unit (e.g. g vs kg, ml vs l).
      final dim = a.dim!;
      final displayUnit = UnitConversion.preferredDisplayUnit(dim, a.baseSum);
      final displayValue = UnitConversion.fromBase(a.baseSum, displayUnit);

      items.add(
        ShoppingListItem(
          name: a.name,
          quantity: Quantity(displayValue, displayUnit),
          unit: displayUnit,
          category: category,
        ),
      );
    }

    // Sort: by category name (stable-ish) then by item name.
    // UI can apply a custom category order later.
    items.sort((x, y) {
      final c = x.category.name.compareTo(y.category.name);
      if (c != 0) return c;
      return x.name.compareTo(y.name);
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

  // base-mode (mass/volume/count): sum in base units
  final UnitDimension? dim;
  double baseSum;

  // unknown-mode: sum in original unit
  final Unit? unknownUnit;
  double? unknownSum;

  // no-qty-mode
  final bool hasNoQuantity;

  _Accumulator.base(this.name, this.dim)
      : baseSum = 0,
        unknownUnit = null,
        unknownSum = null,
        hasNoQuantity = false;

  _Accumulator.unknownUnit(this.name, Unit unit)
      : dim = UnitDimension.unknown,
        baseSum = 0,
        unknownUnit = unit,
        unknownSum = 0,
        hasNoQuantity = false;

  _Accumulator.noQuantity(this.name)
      : dim = null,
        baseSum = 0,
        unknownUnit = null,
        unknownSum = null,
        hasNoQuantity = true;
}

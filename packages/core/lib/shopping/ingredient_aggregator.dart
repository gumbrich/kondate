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
  static ShoppingList fromRecipes(
    List<Recipe> recipes, {
    required double targetServings,
  }) {
    final Map<String, _Accumulator> acc = {};

    for (final Recipe recipe in recipes) {
      final double factor = _scaleFactor(recipe.defaultServings, targetServings);

      for (final line in recipe.ingredients) {
        final String normalized = line.normalizedName?.trim().isNotEmpty == true
            ? line.normalizedName!.trim()
            : IngredientNameNormalizerDe.normalize(line.raw);

        final String displayName = _makeDisplayName(normalized);

        final Quantity? scaled = line.quantity?.scale(factor);

        if (scaled == null) {
          final String key = '${normalized}__noqty';
          acc.putIfAbsent(
            key,
            () => _Accumulator.noQuantity(normalized, displayName),
          );
          continue;
        }

        final UnitDimension dim = UnitConversion.dimension(scaled.unit);

        if (dim == UnitDimension.unknown) {
          final String key = '${normalized}__unknown__${scaled.unit.name}';
          final _Accumulator a = acc.putIfAbsent(
            key,
            () => _Accumulator.unknownUnit(normalized, displayName, scaled.unit),
          );
          a.unknownSum = (a.unknownSum ?? 0) + scaled.value;
          continue;
        }

        final double baseValue = UnitConversion.toBase(scaled.value, scaled.unit);
        final String key = '${normalized}__${dim.name}';

        final _Accumulator a = acc.putIfAbsent(
          key,
          () => _Accumulator.base(normalized, displayName, dim),
        );
        a.baseSum += baseValue;
      }
    }

    final List<ShoppingListItem> items = <ShoppingListItem>[];

    for (final _Accumulator a in acc.values) {
      final category = CategoryClassifierDe.classify(a.name);

      if (a.hasNoQuantity) {
        items.add(
          ShoppingListItem(
            name: a.name,
            displayName: a.displayName,
            quantity: null,
            unit: Unit.unknown,
            category: category,
          ),
        );
        continue;
      }

      if (a.dim == UnitDimension.unknown) {
        final Unit u = a.unknownUnit ?? Unit.unknown;
        items.add(
          ShoppingListItem(
            name: a.name,
            displayName: a.displayName,
            quantity: Quantity(a.unknownSum ?? 0, u),
            unit: u,
            category: category,
          ),
        );
        continue;
      }

      final UnitDimension dim = a.dim!;
      final Unit displayUnit =
          UnitConversion.preferredDisplayUnit(dim, a.baseSum);
      final double displayValue =
          UnitConversion.fromBase(a.baseSum, displayUnit);

      items.add(
        ShoppingListItem(
          name: a.name,
          displayName: a.displayName,
          quantity: Quantity(displayValue, displayUnit),
          unit: displayUnit,
          category: category,
        ),
      );
    }

    items.sort((ShoppingListItem x, ShoppingListItem y) {
      final int c = x.category.name.compareTo(y.category.name);
      if (c != 0) return c;
      return x.displayName.compareTo(y.displayName);
    });

    return ShoppingList(items: items);
  }

  static double _scaleFactor(double? defaultServings, double targetServings) {
    if (defaultServings == null || defaultServings <= 0) return 1.0;
    return targetServings / defaultServings;
  }

  static String _makeDisplayName(String normalized) {
    if (normalized.isEmpty) return normalized;
    return normalized[0].toUpperCase() + normalized.substring(1);
  }
}

class _Accumulator {
  final String name;
  final String displayName;

  final UnitDimension? dim;
  double baseSum;

  final Unit? unknownUnit;
  double? unknownSum;

  final bool hasNoQuantity;

  _Accumulator.base(this.name, this.displayName, this.dim)
      : baseSum = 0,
        unknownUnit = null,
        unknownSum = null,
        hasNoQuantity = false;

  _Accumulator.unknownUnit(this.name, this.displayName, Unit unit)
      : dim = UnitDimension.unknown,
        baseSum = 0,
        unknownUnit = unit,
        unknownSum = 0,
        hasNoQuantity = false;

  _Accumulator.noQuantity(this.name, this.displayName)
      : dim = null,
        baseSum = 0,
        unknownUnit = null,
        unknownSum = null,
        hasNoQuantity = true;
}

import '../units/quantity.dart';
import '../units/unit.dart';
import 'category_de.dart';

class ShoppingListItem {
  /// Internal merge key / normalized key.
  final String name;

  /// User-facing German label.
  final String displayName;

  final Quantity? quantity;
  final Unit unit;
  final CategoryDe category;

  const ShoppingListItem({
    required this.name,
    required this.displayName,
    required this.quantity,
    required this.unit,
    required this.category,
  });
}

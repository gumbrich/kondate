import '../units/quantity.dart';
import '../units/unit.dart';
import 'category_de.dart';

class ShoppingListItem {
  final String name;
  final Quantity? quantity;
  final Unit unit;
  final CategoryDe category;

  const ShoppingListItem({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.category,
  });
}

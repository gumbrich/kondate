import '../units/quantity.dart';
import '../units/unit.dart';

class ShoppingListItem {
  final String name; // German display name for now
  final Quantity? quantity; // null = "some amount"
  final Unit unit; // convenience, mirrors quantity.unit when quantity != null

  const ShoppingListItem({
    required this.name,
    required this.quantity,
    required this.unit,
  });
}

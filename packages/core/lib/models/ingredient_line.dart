import '../units/quantity.dart';

class IngredientLine {
  final String raw;
  final Quantity? quantity;

  /// Later: a canonical token for merging ("tomato", "olive_oil"...).
  final String? normalizedName;

  const IngredientLine({
    required this.raw,
    this.quantity,
    this.normalizedName,
  });
}

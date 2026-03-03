import 'unit.dart';

class Quantity {
  final double value;
  final Unit unit;

  const Quantity(this.value, this.unit);

  Quantity scale(double factor) => Quantity(value * factor, unit);
}

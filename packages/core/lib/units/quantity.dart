import 'unit.dart';
import 'unit_conversion.dart';
import 'unit_dimension.dart';

class Quantity {
  final double value;
  final Unit unit;

  const Quantity(this.value, this.unit);

  Quantity scale(double factor) => Quantity(value * factor, unit);
}

extension QuantityConversion on Quantity {
  UnitDimension get dimension => UnitConversion.dimension(unit);

  double toBaseValue() => UnitConversion.toBase(value, unit);

  Quantity toPreferredDisplay() {
    final dim = dimension;
    if (dim == UnitDimension.unknown) return this;

    final base = toBaseValue();
    final u = UnitConversion.preferredDisplayUnit(dim, base);
    final v = UnitConversion.fromBase(base, u);
    return Quantity(v, u);
  }
}

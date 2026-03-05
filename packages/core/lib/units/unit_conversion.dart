import 'unit.dart';
import 'unit_dimension.dart';

class UnitConversion {
  static UnitDimension dimension(Unit u) {
    // Adjust these cases to match your existing Unit enum.
    switch (u) {
      // Mass
      case Unit.gram:
      case Unit.kilogram:
        return UnitDimension.mass;

      // Volume
      case Unit.milliliter:
      case Unit.liter:
      case Unit.teaspoon:
      case Unit.tablespoon:
        return UnitDimension.volume;

      // Count
      case Unit.piece:
      case Unit.can:
      case Unit.clove:
        return UnitDimension.count;

      default:
        return UnitDimension.unknown;
    }
  }

  /// Converts a value in unit `from` to the base unit of its dimension.
  /// Base units:
  /// - mass: gram
  /// - volume: milliliter
  /// - count: piece (factor 1)
  static double toBase(double value, Unit from) {
    switch (from) {
      // Mass → grams
      case Unit.gram:
        return value;
      case Unit.kilogram:
        return value * 1000.0;

      // Volume → milliliters
      case Unit.milliliter:
        return value;
      case Unit.liter:
        return value * 1000.0;
      case Unit.teaspoon:
        return value * 5.0; // tsp
      case Unit.tablespoon:
        return value * 15.0; // tbsp

      // Count (no cross conversion to mass/volume in MVP)
      case Unit.piece:
      case Unit.can:
      case Unit.clove:
        return value;

      default:
        return value;
    }
  }

  /// Converts a base value to a target unit within the same dimension.
  static double fromBase(double baseValue, Unit to) {
    switch (to) {
      // grams → mass units
      case Unit.gram:
        return baseValue;
      case Unit.kilogram:
        return baseValue / 1000.0;

      // milliliters → volume units
      case Unit.milliliter:
        return baseValue;
      case Unit.liter:
        return baseValue / 1000.0;
      case Unit.teaspoon:
        return baseValue / 5.0;
      case Unit.tablespoon:
        return baseValue / 15.0;

      // count
      case Unit.piece:
      case Unit.can:
      case Unit.clove:
        return baseValue;

      default:
        return baseValue;
    }
  }

  /// Choose a nice display unit for a base value.
  /// - mass: >= 1000g -> kg
  /// - volume: >= 1000ml -> l
  /// - count: keep piece
  static Unit preferredDisplayUnit(UnitDimension dim, double baseValue) {
    switch (dim) {
      case UnitDimension.mass:
        return baseValue >= 1000.0 ? Unit.kilogram : Unit.gram;
      case UnitDimension.volume:
        return baseValue >= 1000.0 ? Unit.liter : Unit.milliliter;
      case UnitDimension.count:
        return Unit.piece;
      case UnitDimension.unknown:
        return Unit.unknown;
    }
  }

  static Unit baseUnit(UnitDimension dim) {
    switch (dim) {
      case UnitDimension.mass:
        return Unit.gram;
      case UnitDimension.volume:
        return Unit.milliliter;
      case UnitDimension.count:
        return Unit.piece;
      case UnitDimension.unknown:
        return Unit.unknown;
    }
  }
}

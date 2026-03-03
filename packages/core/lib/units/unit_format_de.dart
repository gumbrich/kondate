import 'unit.dart';

class UnitFormatDe {
  static String short(Unit unit) {
    return switch (unit) {
      Unit.gram => 'g',
      Unit.kilogram => 'kg',
      Unit.milliliter => 'ml',
      Unit.liter => 'l',
      Unit.teaspoon => 'TL',
      Unit.tablespoon => 'EL',
      Unit.pinch => 'Prise',
      Unit.piece => 'Stk.',
      Unit.can => 'Dose',
      Unit.clove => 'Zehe',
      Unit.bunch => 'Bund',
      Unit.packet => 'Pck.',
      Unit.unknown => '',
    };
  }
}

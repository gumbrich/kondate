import 'unit.dart';

class UnitLexiconDe {
  static final Map<String, Unit> _map = {
    // mass
    'g': Unit.gram,
    'gr': Unit.gram,
    'gram': Unit.gram,
    'gramm': Unit.gram,
    'kg': Unit.kilogram,
    'kilogramm': Unit.kilogram,

    // volume
    'ml': Unit.milliliter,
    'milliliter': Unit.milliliter,
    'l': Unit.liter,
    'liter': Unit.liter,

    // spoons
    'tl': Unit.teaspoon,
    'teelöffel': Unit.teaspoon,
    'teeloeffel': Unit.teaspoon,
    'el': Unit.tablespoon,
    'esslöffel': Unit.tablespoon,
    'essloeffel': Unit.tablespoon,
    'eßlöffel': Unit.tablespoon,
    'eßloeffel': Unit.tablespoon,

    // common recipe units
    'prise': Unit.pinch,
    'prisen': Unit.pinch,

    'stück': Unit.piece,
    'stueck': Unit.piece,
    'stk': Unit.piece,
    'st': Unit.piece,

    'dose': Unit.can,
    'dosen': Unit.can,

    'zehe': Unit.clove,
    'zehen': Unit.clove,

    'bund': Unit.bunch,
    'bünde': Unit.bunch,
    'buende': Unit.bunch,

    'päckchen': Unit.packet,
    'paeckchen': Unit.packet,
    'pck': Unit.packet,
    'pck.': Unit.packet,
    'päckl': Unit.packet,
    'paeckl': Unit.packet,
  };

  static Unit? lookup(String token) {
    final t = token.trim().toLowerCase();
    return _map[t];
  }
}

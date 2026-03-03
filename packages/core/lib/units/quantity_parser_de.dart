import 'quantity.dart';
import 'unit.dart';
import 'unit_lexicon_de.dart';

class QuantityParserDe {
  /// Tries to parse a leading quantity + unit from an ingredient line.
  /// Returns null if no confident parse.
  static Quantity? parseLeadingQuantity(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;

    // Examples:
    // "1,5 EL Olivenöl"
    // "2 Dosen Tomaten"
    // "3-4 Zehen Knoblauch" -> take 3
    // "½ TL Salz" -> not supported yet (fraction glyphs), returns null

    final m = RegExp(r'^(\d+(?:[.,]\d+)?)(?:\s*-\s*\d+(?:[.,]\d+)?)?\s+([^\s]+)')
        .firstMatch(s);
    if (m == null) return null;

    final numberToken = m.group(1);
    final unitToken = m.group(2);

    if (numberToken == null || unitToken == null) return null;

    final value = double.tryParse(numberToken.replaceAll(',', '.'));
    if (value == null) return null;

    // Normalize unit token by stripping trailing punctuation like "." or ","
    final cleanedUnit = unitToken.replaceAll(RegExp(r'[.,;:]$'), '');

    final unit = UnitLexiconDe.lookup(cleanedUnit) ?? _maybePluralUnit(cleanedUnit);
    if (unit == null) return null;

    return Quantity(value, unit);
  }

  static Unit? _maybePluralUnit(String token) {
    // very small heuristic: handle common plural forms where token isn't in map
    final t = token.toLowerCase();
    if (t.endsWith('n')) {
      return UnitLexiconDe.lookup(t.substring(0, t.length - 1));
    }
    if (t.endsWith('en')) {
      return UnitLexiconDe.lookup(t.substring(0, t.length - 2));
    }
    return null;
  }
}

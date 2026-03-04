class IngredientNameNormalizerDe {
  /// Very simple MVP normalizer:
  /// - strips leading "number + token" like "1,5 EL" or "2 Dosen"
  /// - lowercases
  /// - trims
  static String normalize(String raw) {
    var s = raw.trim();

    // Remove leading quantity + unit token if present:
    // e.g. "1,5 EL Olivenöl" -> "Olivenöl"
    final m = RegExp(r'^(\d+(?:[.,]\d+)?)(?:\s*-\s*\d+(?:[.,]\d+)?)?\s+([^\s]+)\s+(.*)$')
        .firstMatch(s);
    if (m != null) {
      final rest = m.group(3);
      if (rest != null && rest.trim().isNotEmpty) {
        s = rest.trim();
      }
    }

    return s.toLowerCase();
  }
}

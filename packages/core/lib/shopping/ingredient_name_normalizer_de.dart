class IngredientNameNormalizerDe {
  /// German MVP normalizer:
  /// - strips leading quantity, with or without a unit token
  /// - lowercases
  /// - normalizes umlaut spellings
  /// - removes some common adjectives/noise
  /// - singularizes a few common plural endings
  static String normalize(String raw) {
    String s = raw.trim();

    // Case 1:
    // "1,5 EL Olivenöl" -> "Olivenöl"
    // "2 Dosen Tomaten" -> "Tomaten"
    final RegExpMatch? quantityAndUnitMatch = RegExp(
      r'^(\d+(?:[.,]\d+)?)(?:\s*-\s*\d+(?:[.,]\d+)?)?\s+([^\s]+)\s+(.*)$',
    ).firstMatch(s);

    if (quantityAndUnitMatch != null) {
      final String? possibleRest = quantityAndUnitMatch.group(3);
      if (possibleRest != null && possibleRest.trim().isNotEmpty) {
        s = possibleRest.trim();
      }
    } else {
      // Case 2:
      // "2 Zwiebeln" -> "Zwiebeln"
      // "3 Tomaten" -> "Tomaten"
      final RegExpMatch? quantityOnlyMatch = RegExp(
        r'^(\d+(?:[.,]\d+)?)(?:\s*-\s*\d+(?:[.,]\d+)?)?\s+(.*)$',
      ).firstMatch(s);

      if (quantityOnlyMatch != null) {
        final String? possibleRest = quantityOnlyMatch.group(2);
        if (possibleRest != null && possibleRest.trim().isNotEmpty) {
          s = possibleRest.trim();
        }
      }
    }

    s = s.toLowerCase();

    // Normalize alternative umlaut spellings.
    s = s
        .replaceAll('ae', 'ä')
        .replaceAll('oe', 'ö')
        .replaceAll('ue', 'ü');

    // Normalize a few explicit common forms.
    s = s.replaceAll('olivenoel', 'olivenöl');

    // Remove punctuation lightly.
    s = s.replaceAll(RegExp(r'[(),.;:]'), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();

    // Remove common non-essential descriptors.
    const List<String> noiseWords = <String>[
      'frisch',
      'frische',
      'frischer',
      'frischen',
      'gehackt',
      'fein',
      'klein',
      'gerieben',
      'gemahlen',
      'bio',
    ];

    final List<String> tokens = s
        .split(' ')
        .where((String t) => t.isNotEmpty && !noiseWords.contains(t))
        .toList();

    if (tokens.isEmpty) {
      return s;
    }

    String normalized = tokens.join(' ');

    final List<String> words = normalized.split(' ');
    final String last = words.last;
    words[words.length - 1] = _singularize(last);

    normalized = words.join(' ').trim();
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');

    return normalized;
  }

  static String _singularize(String word) {
    const Map<String, String> special = <String, String>{
      'zwiebeln': 'zwiebel',
      'tomaten': 'tomate',
      'kartoffeln': 'kartoffel',
      'möhren': 'möhre',
      'karotten': 'karotte',
      'paprika': 'paprika',
      'nudeln': 'nudel',
      'eier': 'ei',
      'zehen': 'zehe',
      'dosen': 'dose',
      'frühlingszwiebeln': 'frühlingszwiebel',
      'bohnen': 'bohne',
      'linsen': 'linse',
    };

    if (special.containsKey(word)) {
      return special[word]!;
    }

    if (word.endsWith('en') && word.length > 4) {
      return word.substring(0, word.length - 2);
    }
    if (word.endsWith('n') && word.length > 4) {
      return word.substring(0, word.length - 1);
    }
    if (word.endsWith('s') && word.length > 4) {
      return word.substring(0, word.length - 1);
    }

    return word;
  }
}

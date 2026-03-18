class IngredientFormatter {
  static String format({
    required double quantity,
    required String unit,
    required String name,
  }) {
    final _IngredientNameParts parts = _normalizeNameDetailed(name);

    final String q = _formatQuantity(quantity);
    final String displayUnit = _formatDisplayUnit(
      unit: unit,
      normalizedName: parts.name,
      note: parts.note,
    );

    if (displayUnit.isEmpty) {
      if (parts.note == null || parts.note!.isEmpty) {
        return '$q ${parts.name}';
      }
      return '$q ${parts.name} (${parts.note})';
    }

    if (parts.note == null || parts.note!.isEmpty) {
      return '$q $displayUnit ${parts.name}';
    }

    return '$q $displayUnit ${parts.name} (${parts.note})';
  }

  static String normalizeName(String input) {
    return _normalizeNameDetailed(input).name;
  }

  static String _formatQuantity(double q) {
    if (q == q.roundToDouble()) {
      return q.toInt().toString();
    }

    String s = q.toStringAsFixed(2);
    s = s.replaceAll(RegExp(r'0+$'), '');
    s = s.replaceAll(RegExp(r'\.$'), '');
    return s.replaceAll('.', ',');
  }

  static String _formatDisplayUnit({
    required String unit,
    required String normalizedName,
    required String? note,
  }) {
    final String u = unit.toLowerCase().trim();

    final bool looksLikeCan = note != null &&
        (note.contains('400 g') ||
            note.contains('500 g') ||
            note.contains('800 g') ||
            note.contains('Dose'));

    switch (u) {
      case 'gram':
        return 'g';
      case 'kilogram':
        return 'kg';
      case 'milliliter':
        return 'ml';
      case 'liter':
        return 'l';
      case 'piece':
        if (looksLikeCan &&
            (normalizedName.contains('Tomaten') ||
                normalizedName.contains('Kokosmilch') ||
                normalizedName.contains('Bohnen') ||
                normalizedName.contains('Mais'))) {
          return 'Dose';
        }
        return 'Stk.';
      case 'bunch':
        return 'Bund';
      case 'teaspoon':
        return 'TL';
      case 'tablespoon':
        return 'EL';
      default:
        return '';
    }
  }

  static _IngredientNameParts _normalizeNameDetailed(String input) {
    String s = input.trim();
    if (s.isEmpty) {
      return const _IngredientNameParts(name: '');
    }

    s = _normalizeWhitespace(s);
    s = _normalizeAsciiVariants(s);
    s = s.toLowerCase();

    String? extractedNote;

    // Häufige Gewichts-/Packungsinfos aus dem Namen herausziehen
    final RegExp weightPattern = RegExp(r'\b(\d+\s?(g|kg|ml|l))\b');
    final Match? weightMatch = weightPattern.firstMatch(s);
    if (weightMatch != null) {
      extractedNote = weightMatch.group(1);
      s = s.replaceFirst(weightMatch.group(0)!, '');
    }

    // störende Zusätze
    s = s.replaceAll(RegExp(r'\boder tk\b'), '');
    s = s.replaceAll(RegExp(r'\btk\b'), '');
    s = s.replaceAll(RegExp(r'\bfrisch\b'), '');
    s = s.replaceAll(RegExp(r'\bev[.]?\b'), '');
    s = s.replaceAll(RegExp(r'\bevtl[.]?\b'), '');
    s = s.replaceAll(RegExp(r'\bnach geschmack\b'), '');
    s = s.replaceAll(RegExp(r'\boptional\b'), '');
    s = s.replaceAll(RegExp(r'\bzum bestreuen\b'), '');
    s = s.replaceAll(RegExp(r'\bzur deko\b'), '');

    // Chefkoch-/Parser-Reste
    s = s.replaceAll(RegExp(r'\blasagneplatte\s*n\b'), 'lasagneplatten');
    s = s.replaceAll(RegExp(r'\bzwiebel\s*n\b'), 'zwiebeln');
    s = s.replaceAll(RegExp(r'\bknoblauchzehe\s*n\b'), 'knoblauchzehen');
    s = s.replaceAll(RegExp(r'\bkarotte\s*n\b'), 'karotten');
    s = s.replaceAll(RegExp(r'\bmöhre\s*n\b'), 'möhren');
    s = s.replaceAll(RegExp(r'\btomate\s*n\b'), 'tomaten');
    s = s.replaceAll(RegExp(r'\bn\b$'), '');

    // häufige Umstellungen
    s = s.replaceAll(RegExp(r'\btomaten geschälte\b'), 'geschälte tomaten');
    s = s.replaceAll(RegExp(r'\btomaten gehackte\b'), 'gehackte tomaten');
    s = s.replaceAll(RegExp(r'\btomaten passierte\b'), 'passierte tomaten');
    s = s.replaceAll(RegExp(r'\bhackfleisch gemischte?s\b'), 'gemischtes hackfleisch');
    s = s.replaceAll(RegExp(r'\bgemischte?s hackfleisch\b'), 'gemischtes hackfleisch');
    s = s.replaceAll(RegExp(r'\bgeriebener parmesan\b'), 'parmesan, gerieben');
    s = s.replaceAll(RegExp(r'\bgeriebene?r? parmesan\b'), 'parmesan, gerieben');

    s = _normalizeWhitespace(s);

    final String? exact = _exactCorrections[s];
    if (exact != null) {
      return _IngredientNameParts(
        name: exact,
        note: extractedNote,
      );
    }

    // leicht intelligentere Spezialfälle
    if (s.contains('geschälte tomaten')) {
      return _IngredientNameParts(
        name: 'Geschälte Tomaten',
        note: extractedNote,
      );
    }

    if (s.contains('gehackte tomaten')) {
      return _IngredientNameParts(
        name: 'Gehackte Tomaten',
        note: extractedNote,
      );
    }

    if (s.contains('passierte tomaten')) {
      return _IngredientNameParts(
        name: 'Passierte Tomaten',
        note: extractedNote,
      );
    }

    if (s.contains('gemischtes hackfleisch')) {
      return _IngredientNameParts(
        name: 'Gemischtes Hackfleisch',
        note: extractedNote,
      );
    }

    if (s.contains('parmesan')) {
      if (s.contains('gerieben')) {
        return _IngredientNameParts(
          name: 'Parmesan, gerieben',
          note: extractedNote,
        );
      }
      return _IngredientNameParts(
        name: 'Parmesan',
        note: extractedNote,
      );
    }

    if (s.contains('petersilie')) {
      return _IngredientNameParts(
        name: 'Petersilie',
        note: extractedNote,
      );
    }

    if (s.contains('lasagneplatten')) {
      return _IngredientNameParts(
        name: 'Lasagneplatten',
        note: extractedNote,
      );
    }

    s = _titleCaseGerman(s);

    return _IngredientNameParts(
      name: s,
      note: extractedNote,
    );
  }

  static String _normalizeWhitespace(String s) {
    return s.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  static String _normalizeAsciiVariants(String s) {
    return s
        .replaceAll('ae', 'ä')
        .replaceAll('oe', 'ö')
        .replaceAll('ue', 'ü')
        .replaceAll('Ae', 'Ä')
        .replaceAll('Oe', 'Ö')
        .replaceAll('Ue', 'Ü');
  }

  static String _titleCaseGerman(String s) {
    if (s.isEmpty) return s;

    final List<String> lowerWords = <String>[
      'und',
      'oder',
      'mit',
      'ohne',
      'in',
      'aus',
      'für',
      'vom',
      'von',
      'zum',
      'zur',
      'am',
      'im',
    ];

    final List<String> words = s.split(' ');
    final List<String> result = <String>[];

    for (int i = 0; i < words.length; i++) {
      final String w = words[i];
      if (w.isEmpty) continue;

      if (i > 0 && lowerWords.contains(w)) {
        result.add(w);
        continue;
      }

      if (w.length == 1) {
        result.add(w.toUpperCase());
        continue;
      }

      result.add(w[0].toUpperCase() + w.substring(1));
    }

    return result.join(' ');
  }

  static final Map<String, String> _exactCorrections = <String, String>{
    // Gemüse
    'zwiebel': 'Zwiebel',
    'zwiebeln': 'Zwiebeln',
    'rote zwiebel': 'Rote Zwiebel',
    'rote zwiebeln': 'Rote Zwiebeln',
    'knoblauch': 'Knoblauch',
    'knoblauchzehe': 'Knoblauchzehe',
    'knoblauchzehen': 'Knoblauchzehen',
    'karotte': 'Karotte',
    'karotten': 'Karotten',
    'möhre': 'Möhre',
    'möhren': 'Möhren',
    'sellerie': 'Sellerie',
    'staudensellerie': 'Staudensellerie',
    'paprika': 'Paprika',
    'rote paprika': 'Rote Paprika',
    'gelbe paprika': 'Gelbe Paprika',
    'grüne paprika': 'Grüne Paprika',
    'zucchini': 'Zucchini',
    'aubergine': 'Aubergine',
    'champignon': 'Champignon',
    'champignons': 'Champignons',
    'brokkoli': 'Brokkoli',
    'blumenkohl': 'Blumenkohl',
    'spinat': 'Spinat',
    'blattspinat': 'Blattspinat',
    'gurke': 'Gurke',
    'tomate': 'Tomate',
    'tomaten': 'Tomaten',
    'cherrytomaten': 'Cherrytomaten',
    'kartoffel': 'Kartoffel',
    'kartoffeln': 'Kartoffeln',
    'süßkartoffel': 'Süßkartoffel',
    'süßkartoffeln': 'Süßkartoffeln',
    'lauch': 'Lauch',
    'porree': 'Porree',
    'frühlingszwiebeln': 'Frühlingszwiebeln',
    'frühlingszwiebel': 'Frühlingszwiebel',
    'ingwer': 'Ingwer',
    'chili': 'Chili',
    'mais': 'Mais',
    'erbsen': 'Erbsen',
    'linsen': 'Linsen',
    'kichererbsen': 'Kichererbsen',
    'bohnen': 'Bohnen',
    'weiße bohnen': 'Weiße Bohnen',
    'kidneybohnen': 'Kidneybohnen',

    // Kräuter
    'petersilie': 'Petersilie',
    'schnittlauch': 'Schnittlauch',
    'basilikum': 'Basilikum',
    'oregano': 'Oregano',
    'thymian': 'Thymian',
    'rosmarin': 'Rosmarin',
    'dill': 'Dill',
    'koriander': 'Koriander',

    // Tomatenprodukte
    'geschälte tomaten': 'Geschälte Tomaten',
    'gehackte tomaten': 'Gehackte Tomaten',
    'passierte tomaten': 'Passierte Tomaten',
    'tomatenmark': 'Tomatenmark',

    // Milchprodukte
    'butter': 'Butter',
    'milch': 'Milch',
    'sahne': 'Sahne',
    'schlagsahne': 'Schlagsahne',
    'frischkäse': 'Frischkäse',
    'quark': 'Quark',
    'joghurt': 'Joghurt',
    'naturjoghurt': 'Naturjoghurt',
    'schmand': 'Schmand',
    'saure sahne': 'Saure Sahne',
    'crème fraîche': 'Crème fraîche',
    'creme fraiche': 'Crème fraîche',
    'mascarpone': 'Mascarpone',
    'mozzarella': 'Mozzarella',
    'parmesan': 'Parmesan',
    'parmesan gerieben': 'Parmesan, gerieben',
    'gouda': 'Gouda',
    'emmentaler': 'Emmentaler',
    'feta': 'Feta',
    'ricotta': 'Ricotta',

    // Fleisch/Fisch
    'hackfleisch': 'Hackfleisch',
    'gemischtes hackfleisch': 'Gemischtes Hackfleisch',
    'hackfleisch gemischt': 'Gemischtes Hackfleisch',
    'hackfleisch gemischte': 'Gemischtes Hackfleisch',
    'rinderhack': 'Rinderhack',
    'rinderhackfleisch': 'Rinderhackfleisch',
    'hähnchenbrust': 'Hähnchenbrust',
    'hähnchenbrustfilet': 'Hähnchenbrustfilet',
    'hähnchenfilet': 'Hähnchenfilet',
    'speck': 'Speck',
    'schinken': 'Schinken',
    'lachs': 'Lachs',
    'thunfisch': 'Thunfisch',

    // Trockenwaren
    'mehl': 'Mehl',
    'weizenmehl': 'Weizenmehl',
    'zucker': 'Zucker',
    'brauner zucker': 'Brauner Zucker',
    'salz': 'Salz',
    'pfeffer': 'Pfeffer',
    'muskat': 'Muskat',
    'zimt': 'Zimt',
    'paprikapulver': 'Paprikapulver',
    'currypulver': 'Currypulver',
    'backpulver': 'Backpulver',
    'natron': 'Natron',
    'hefe': 'Hefe',
    'olivenöl': 'Olivenöl',
    'öl': 'Öl',
    'sonnenblumenöl': 'Sonnenblumenöl',
    'essig': 'Essig',
    'balsamico': 'Balsamico',
    'sojasoße': 'Sojasoße',
    'sojasauce': 'Sojasoße',
    'honig': 'Honig',
    'senf': 'Senf',
    'brühe': 'Brühe',
    'gemüsebrühe': 'Gemüsebrühe',
    'hühnerbrühe': 'Hühnerbrühe',

    // Pasta / Reis
    'nudeln': 'Nudeln',
    'spaghetti': 'Spaghetti',
    'penne': 'Penne',
    'reis': 'Reis',
    'basmatireis': 'Basmatireis',
    'lasagneplatten': 'Lasagneplatten',
    'lasagneplatte': 'Lasagneplatte',

    // Eier
    'ei': 'Ei',
    'eier': 'Eier',
  };
}

class _IngredientNameParts {
  final String name;
  final String? note;

  const _IngredientNameParts({
    required this.name,
    this.note,
  });
}

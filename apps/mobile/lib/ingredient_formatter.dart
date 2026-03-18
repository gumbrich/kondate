class IngredientFormatter {
  static String format({
    required double quantity,
    required String unit,
    required String name,
  }) {
    final IngredientInterpretation parsed =
        IngredientParser.parse(name, quantity, unit);

    final String q = _formatQuantity(parsed.displayQuantity);
    final String effectiveUnit =
        (parsed.unit == null || parsed.unit!.isEmpty)
            ? _inferUnit(parsed.name)
            : parsed.unit!;

    if (effectiveUnit.isEmpty) {
      if (parsed.note != null && parsed.note!.isNotEmpty) {
        return '$q ${parsed.name} (${parsed.note})';
      }
      return '$q ${parsed.name}';
    }

    if (parsed.note != null && parsed.note!.isNotEmpty) {
      return '$q $effectiveUnit ${parsed.name} (${parsed.note})';
    }

    return '$q $effectiveUnit ${parsed.name}';
  }

  static String normalizeName(String input) {
    return IngredientParser.parse(input, 1, '').name;
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

  static String _inferUnit(String name) {
    final String n = name.toLowerCase();

    if (n.contains('oregano') ||
        n.contains('thymian') ||
        n.contains('rosmarin') ||
        n.contains('paprikapulver') ||
        n.contains('currypulver') ||
        n.contains('zimt')) {
      return 'TL';
    }

    if (n.contains('öl')) return 'EL';

    if (n.contains('brühe')) return 'ml';

    if (n.contains('milch') || n.contains('sahne')) return 'ml';

    if (n.contains('spaghetti') ||
        n.contains('nudeln') ||
        n.contains('reis')) {
      return 'g';
    }

    if (n.contains('tomaten') ||
        n.contains('tomatenmark') ||
        n.contains('ketchup') ||
        n.contains('hackfleisch') ||
        n.contains('mehl') ||
        n.contains('butter')) {
      return 'g';
    }

    return '';
  }
}

class IngredientInterpretation {
  final String name;
  final double displayQuantity;
  final String? unit;
  final String? note;

  const IngredientInterpretation({
    required this.name,
    required this.displayQuantity,
    this.unit,
    this.note,
  });

  IngredientInterpretation copyWith({
    String? name,
    double? displayQuantity,
    String? unit,
    String? note,
  }) {
    return IngredientInterpretation(
      name: name ?? this.name,
      displayQuantity: displayQuantity ?? this.displayQuantity,
      unit: unit ?? this.unit,
      note: note ?? this.note,
    );
  }
}

class IngredientParser {
  static IngredientInterpretation parse(
    String rawName,
    double quantity,
    String rawUnit,
  ) {
    String name = rawName.trim();
    if (name.isEmpty) {
      return IngredientInterpretation(
        name: '',
        displayQuantity: quantity,
        unit: _mapUnit(rawUnit),
      );
    }

    name = _normalizeAsciiVariants(name);
    name = name.toLowerCase();
    name = _normalizeWhitespace(name);

    String? note;

    final Match? amountMatch =
        RegExp(r'\b(\d+\s?(?:g|kg|ml|l))\b').firstMatch(name);
    if (amountMatch != null) {
      note = amountMatch.group(1);
      name = name.replaceFirst(amountMatch.group(0)!, '');
    }

    name = name.replaceAll(RegExp(r'\boder tk\b'), '');
    name = name.replaceAll(RegExp(r'\btk\b'), '');
    name = name.replaceAll(RegExp(r'\bfrisch\b'), '');
    name = name.replaceAll(RegExp(r'\bev[.]?\b'), '');
    name = name.replaceAll(RegExp(r'\bevtl[.]?\b'), '');
    name = name.replaceAll(RegExp(r'\bnach geschmack\b'), '');
    name = name.replaceAll(RegExp(r'\boptional\b'), '');
    name = name.replaceAll(RegExp(r'\bzum bestreuen\b'), '');
    name = name.replaceAll(RegExp(r'\bzur deko\b'), '');
    name = name.replaceAll(RegExp(r'\bmittelgroß\b'), '');
    name = name.replaceAll(RegExp(r'\bmittelgroße\b'), '');
    name = name.replaceAll(RegExp(r'\bklein\b'), '');
    name = name.replaceAll(RegExp(r'\bkleine\b'), '');
    name = name.replaceAll(RegExp(r'\bgroß\b'), '');
    name = name.replaceAll(RegExp(r'\bgroße\b'), '');
    name = name.replaceAll(RegExp(r'\bz\.?\s*b\.?\b'), '');
    name = name.replaceAll(RegExp(r'\baus dem tetrapack\b'), 'tetrapack');
    name = name.replaceAll(RegExp(r'\baus dem\b'), '');
    name = name.replaceAll(RegExp(r'\bmit kräutern\b'), '');
    name = name.replaceAll(RegExp(r'\bstückige tomaten.*'), 'stückige tomaten');

    name = name.replaceAll(RegExp(r'\blasagneplatte\s*n\b'), 'lasagneplatten');
    name = name.replaceAll(RegExp(r'\bzwiebel\s*n\b'), 'zwiebeln');
    name = name.replaceAll(RegExp(r'\bknoblauchzehe\s*n\b'), 'knoblauchzehen');
    name = name.replaceAll(RegExp(r'\bkarotte\s*n\b'), 'karotten');
    name = name.replaceAll(RegExp(r'\bmöhre\s*n\b'), 'möhren');
    name = name.replaceAll(RegExp(r'\btomate\s*n\b'), 'tomaten');
    name = name.replaceAll(RegExp(r'\bpaprikaschote\s*n\b'), 'paprika');
    name = name.replaceAll(RegExp(r'\bn\b$'), '');

    name = name.replaceAll(RegExp(r'\btomaten geschälte\b'), 'geschälte tomaten');
    name = name.replaceAll(RegExp(r'\btomaten gehackte\b'), 'gehackte tomaten');
    name = name.replaceAll(RegExp(r'\btomaten passierte\b'), 'passierte tomaten');
    name = name.replaceAll(RegExp(r'\btomaten stückige\b'), 'stückige tomaten');
    name = name.replaceAll(
      RegExp(r'\bhackfleisch gemischte?s\b'),
      'gemischtes hackfleisch',
    );
    name = name.replaceAll(
      RegExp(r'\bgemischte?s hackfleisch\b'),
      'gemischtes hackfleisch',
    );
    name = name.replaceAll(
      RegExp(r'\bgeriebener parmesan\b'),
      'parmesan, gerieben',
    );
    name = name.replaceAll(
      RegExp(r'\bgeriebene?r? parmesan\b'),
      'parmesan, gerieben',
    );

    name = _normalizeWhitespace(name);

    final String? exact = _exactCorrections[name];
    if (exact != null) {
      return IngredientInterpretation(
        name: _applySingularIfNeeded(
          name: exact,
          rawUnit: rawUnit,
          quantity: quantity,
        ),
        displayQuantity: quantity,
        unit: _mapUnit(rawUnit),
        note: note,
      );
    }

    if (_containsAny(name, <String>[
      'geschälte tomaten',
      'gehackte tomaten',
      'passierte tomaten',
      'stückige tomaten',
    ])) {
      final String normalizedTomatoes = _normalizeTomatoProduct(name);

      final bool canBeCan = note != null &&
          (note.contains('400 g') ||
              note.contains('500 g') ||
              note.contains('800 g'));

      return IngredientInterpretation(
        name: normalizedTomatoes,
        displayQuantity: quantity,
        unit: canBeCan ? 'Dose' : _fallbackUnit(_mapUnit(rawUnit), 'g'),
        note: note,
      );
    }

    if (name.contains('tomatenmark')) {
      return IngredientInterpretation(
        name: 'Tomatenmark',
        displayQuantity: quantity,
        unit: _fallbackUnit(_mapUnit(rawUnit), 'g'),
        note: note,
      );
    }

    if (name.contains('tomatenketchup') || name.contains('ketchup')) {
      return IngredientInterpretation(
        name: 'Tomatenketchup',
        displayQuantity: quantity,
        unit: _fallbackUnit(_mapUnit(rawUnit), 'g'),
        note: note,
      );
    }

    if (name.contains('hackfleisch')) {
      return IngredientInterpretation(
        name: 'Gemischtes Hackfleisch',
        displayQuantity: quantity,
        unit: _preferWeightUnit(rawUnit, fallback: 'g'),
        note: note,
      );
    }

    if (name.contains('rinderhack')) {
      return IngredientInterpretation(
        name: 'Rinderhackfleisch',
        displayQuantity: quantity,
        unit: _preferWeightUnit(rawUnit, fallback: 'g'),
        note: note,
      );
    }

    if (name.contains('lasagneplatten') || name.contains('lasagneplatte')) {
      return IngredientInterpretation(
        name: 'Lasagneplatten',
        displayQuantity: quantity,
        unit: _preferWeightUnit(rawUnit, fallback: 'g'),
        note: note,
      );
    }

    if (name.contains('spaghetti') || name.contains('nudeln')) {
      return IngredientInterpretation(
        name: _titleCaseGerman(name),
        displayQuantity: quantity,
        unit: _fallbackUnit(_mapUnit(rawUnit), 'g'),
        note: note,
      );
    }

    if (name.contains('petersilie')) {
      return IngredientInterpretation(
        name: 'Petersilie',
        displayQuantity: quantity,
        unit: _preferPieceLikeUnit(rawUnit, fallback: 'Bund'),
        note: note,
      );
    }

    if (name.contains('schnittlauch')) {
      return IngredientInterpretation(
        name: 'Schnittlauch',
        displayQuantity: quantity,
        unit: _preferPieceLikeUnit(rawUnit, fallback: 'Bund'),
        note: note,
      );
    }

    if (name.contains('basilikum')) {
      return IngredientInterpretation(
        name: 'Basilikum',
        displayQuantity: quantity,
        unit: _preferPieceLikeUnit(rawUnit, fallback: 'Bund'),
        note: note,
      );
    }

    if (name.contains('oregano') ||
        name.contains('thymian') ||
        name.contains('rosmarin') ||
        name.contains('paprikapulver') ||
        name.contains('currypulver') ||
        name.contains('zimt')) {
      return IngredientInterpretation(
        name: _titleCaseGerman(name),
        displayQuantity: quantity,
        unit: _mapUnit(rawUnit).isEmpty ? 'TL' : _mapUnit(rawUnit),
        note: note,
      );
    }

    if (name.contains('brühe')) {
      return IngredientInterpretation(
        name: name.contains('hühner')
            ? 'Hühnerbrühe'
            : name.contains('gemüse')
                ? 'Gemüsebrühe'
                : 'Brühe',
        displayQuantity: quantity,
        unit: _mapUnit(rawUnit).isEmpty ? 'ml' : _mapUnit(rawUnit),
        note: note,
      );
    }

    if (name.contains('zwiebel')) {
      final String displayName = quantity == 1 ? 'Zwiebel' : 'Zwiebeln';
      return IngredientInterpretation(
        name: displayName,
        displayQuantity: quantity,
        unit: _preferPieceLikeUnit(rawUnit, fallback: ''),
        note: note,
      );
    }

    if (name.contains('knoblauch')) {
      final String displayName =
          quantity == 1 ? 'Knoblauchzehe' : 'Knoblauchzehen';
      return IngredientInterpretation(
        name: displayName,
        displayQuantity: quantity,
        unit: _preferPieceLikeUnit(rawUnit, fallback: ''),
        note: note,
      );
    }

    if (name.contains('karotte') || name.contains('möhre')) {
      final String displayName = quantity == 1 ? 'Karotte' : 'Karotten';
      return IngredientInterpretation(
        name: displayName,
        displayQuantity: quantity,
        unit: _preferPieceLikeUnit(rawUnit, fallback: ''),
        note: note,
      );
    }

    if (name.contains('parmesan')) {
      return IngredientInterpretation(
        name: name.contains('gerieben') ? 'Parmesan, gerieben' : 'Parmesan',
        displayQuantity: quantity,
        unit: _preferWeightUnit(rawUnit, fallback: 'g'),
        note: note,
      );
    }

    if (name.contains('mozzarella')) {
      return IngredientInterpretation(
        name: 'Mozzarella',
        displayQuantity: quantity,
        unit: _mapUnit(rawUnit),
        note: note,
      );
    }

    if (name.contains('butter')) {
      return IngredientInterpretation(
        name: 'Butter',
        displayQuantity: quantity,
        unit: _preferWeightUnit(rawUnit, fallback: 'g'),
        note: note,
      );
    }

    if (name.contains('mehl')) {
      return IngredientInterpretation(
        name: 'Mehl',
        displayQuantity: quantity,
        unit: _preferWeightUnit(rawUnit, fallback: 'g'),
        note: note,
      );
    }

    if (name.contains('milch')) {
      return IngredientInterpretation(
        name: 'Milch',
        displayQuantity: quantity,
        unit: _preferVolumeUnit(rawUnit, fallback: 'ml'),
        note: note,
      );
    }

    if (name.contains('sahne')) {
      return IngredientInterpretation(
        name: 'Sahne',
        displayQuantity: quantity,
        unit: _preferVolumeUnit(rawUnit, fallback: 'ml'),
        note: note,
      );
    }

    if (name.contains('olivenöl')) {
      return IngredientInterpretation(
        name: 'Olivenöl',
        displayQuantity: quantity,
        unit: _mapUnit(rawUnit),
        note: note,
      );
    }

    if (name.contains('salz')) {
      return IngredientInterpretation(
        name: 'Salz',
        displayQuantity: quantity,
        unit: _mapUnit(rawUnit),
        note: note,
      );
    }

    if (name.contains('pfeffer')) {
      return IngredientInterpretation(
        name: 'Pfeffer',
        displayQuantity: quantity,
        unit: _mapUnit(rawUnit),
        note: note,
      );
    }

    final String fallbackName = _applySingularIfNeeded(
      name: _titleCaseGerman(name),
      rawUnit: rawUnit,
      quantity: quantity,
    );

    return IngredientInterpretation(
      name: fallbackName,
      displayQuantity: quantity,
      unit: _mapUnit(rawUnit),
      note: note,
    );
  }

  static bool _containsAny(String text, List<String> needles) {
    for (final String needle in needles) {
      if (text.contains(needle)) return true;
    }
    return false;
  }

  static String _normalizeTomatoProduct(String name) {
    if (name.contains('geschälte tomaten')) return 'Geschälte Tomaten';
    if (name.contains('gehackte tomaten')) return 'Gehackte Tomaten';
    if (name.contains('passierte tomaten')) return 'Passierte Tomaten';
    if (name.contains('stückige tomaten')) return 'Stückige Tomaten';
    return 'Tomaten';
  }

  static String _fallbackUnit(String mapped, String fallback) {
    return mapped.isEmpty ? fallback : mapped;
  }

  static String _preferWeightUnit(String rawUnit, {required String fallback}) {
    final String mapped = _mapUnit(rawUnit);
    if (mapped == 'g' || mapped == 'kg') return mapped;
    return fallback;
  }

  static String _preferVolumeUnit(String rawUnit, {required String fallback}) {
    final String mapped = _mapUnit(rawUnit);
    if (mapped == 'ml' || mapped == 'l') return mapped;
    return fallback;
  }

  static String _preferPieceLikeUnit(String rawUnit,
      {required String fallback}) {
    final String mapped = _mapUnit(rawUnit);
    if (mapped == 'Stk.' || mapped == 'Bund') return mapped;
    return fallback;
  }

  static String _applySingularIfNeeded({
    required String name,
    required String rawUnit,
    required double quantity,
  }) {
    final String mapped = _mapUnit(rawUnit);

    if ((mapped == 'Stk.' || mapped.isEmpty) && quantity == 1) {
      if (name == 'Zwiebeln') return 'Zwiebel';
      if (name == 'Knoblauchzehen') return 'Knoblauchzehe';
      if (name == 'Karotten') return 'Karotte';
    }

    return name;
  }

  static String _mapUnit(String rawUnit) {
    final String u = rawUnit.toLowerCase().trim();

    if (u.contains('gram')) return 'g';
    if (u.contains('kilogram')) return 'kg';
    if (u.contains('milliliter')) return 'ml';
    if (u.contains('liter')) return 'l';
    if (u.contains('piece')) return 'Stk.';
    if (u.contains('bunch')) return 'Bund';
    if (u.contains('teaspoon')) return 'TL';
    if (u.contains('tablespoon')) return 'EL';

    return '';
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
    'petersilie': 'Petersilie',
    'schnittlauch': 'Schnittlauch',
    'basilikum': 'Basilikum',
    'oregano': 'Oregano',
    'thymian': 'Thymian',
    'rosmarin': 'Rosmarin',
    'dill': 'Dill',
    'koriander': 'Koriander',
    'geschälte tomaten': 'Geschälte Tomaten',
    'gehackte tomaten': 'Gehackte Tomaten',
    'passierte tomaten': 'Passierte Tomaten',
    'stückige tomaten': 'Stückige Tomaten',
    'tomatenmark': 'Tomatenmark',
    'tomatenketchup': 'Tomatenketchup',
    'ketchup': 'Tomatenketchup',
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
    'hackfleisch': 'Hackfleisch',
    'gemischtes hackfleisch': 'Gemischtes Hackfleisch',
    'hackfleisch gemischt': 'Gemischtes Hackfleisch',
    'hackfleisch gemischte': 'Gemischtes Hackfleisch',
    'rinderhack': 'Rinderhackfleisch',
    'rinderhackfleisch': 'Rinderhackfleisch',
    'hähnchenbrust': 'Hähnchenbrust',
    'hähnchenbrustfilet': 'Hähnchenbrustfilet',
    'hähnchenfilet': 'Hähnchenfilet',
    'speck': 'Speck',
    'schinken': 'Schinken',
    'lachs': 'Lachs',
    'thunfisch': 'Thunfisch',
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
    'gemüsebrühe instant': 'Gemüsebrühe',
    'hühnerbrühe': 'Hühnerbrühe',
    'nudeln': 'Nudeln',
    'spaghetti': 'Spaghetti',
    'penne': 'Penne',
    'reis': 'Reis',
    'basmatireis': 'Basmatireis',
    'lasagneplatten': 'Lasagneplatten',
    'lasagneplatte': 'Lasagneplatte',
    'ei': 'Ei',
    'eier': 'Eier',
  };
}

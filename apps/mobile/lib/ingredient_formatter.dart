class IngredientFormatter {
  static String format({
    required double quantity,
    required String unit,
    required String name,
  }) {
    final IngredientInterpretation parsed =
        IngredientParser.parse(name, quantity, unit);

    final String baseUnit =
        (parsed.unit == null || parsed.unit!.isEmpty)
            ? _inferUnit(parsed.name)
            : parsed.unit!;

    final _PackagingResult packaged = _applyPackaging(
      name: parsed.name,
      quantity: parsed.displayQuantity,
      unit: baseUnit,
      note: parsed.note,
    );

    final String q = _formatQuantity(packaged.quantity);
    final String displayUnit = _pluralizeUnit(
      unit: packaged.unit,
      quantity: packaged.quantity,
    );

    if (displayUnit.isEmpty) {
      if (packaged.note != null && packaged.note!.isNotEmpty) {
        return '$q ${packaged.name} (${packaged.note})';
      }
      return '$q ${packaged.name}';
    }

    if (packaged.note != null && packaged.note!.isNotEmpty) {
      return '$q $displayUnit ${packaged.name} (${packaged.note})';
    }

    return '$q $displayUnit ${packaged.name}';
  }

  static String normalizeName(String input) {
    return IngredientParser.parse(input, 1, '').name;
  }

  static String canonicalMergeName(String input) {
    final String normalized = normalizeName(input).toLowerCase();

    switch (normalized) {
      case 'zwiebel':
      case 'zwiebeln':
        return 'zwiebel';
      case 'knoblauchzehe':
      case 'knoblauchzehen':
        return 'knoblauchzehe';
      case 'karotte':
      case 'karotten':
        return 'karotte';
      case 'ei':
      case 'eier':
        return 'ei';
      case 'rote paprika':
        return 'paprika_rot';
      case 'gelbe paprika':
        return 'paprika_gelb';
      case 'grüne paprika':
        return 'paprika_gruen';
      case 'festkochende kartoffel':
      case 'festkochende kartoffeln':
        return 'kartoffel_festkochend';
      default:
        return normalized;
    }
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

    if (n.contains('joghurt') ||
        n.contains('quark') ||
        n.contains('frischkäse') ||
        n.contains('schmand') ||
        n.contains('mascarpone') ||
        n.contains('ricotta')) {
      return 'g';
    }

    if (n.contains('spaghetti') ||
        n.contains('nudeln') ||
        n.contains('reis')) {
      return 'g';
    }

    if (n.contains('tomaten') ||
        n.contains('tomatenmark') ||
        n.contains('ketchup') ||
        n.contains('sojasoße') ||
        n.contains('hackfleisch') ||
        n.contains('mehl') ||
        n.contains('butter') ||
        n.contains('kartoffel')) {
      return 'g';
    }

    return '';
  }

  static _PackagingResult _applyPackaging({
    required String name,
    required double quantity,
    required String unit,
    String? note,
  }) {
    final String n = name.toLowerCase();

    if (n.contains('tomaten') && unit == 'g') {
      const double packSize = 400;
      if (quantity >= 300) {
        final int cans = (quantity / packSize).round().clamp(1, 999);
        return _PackagingResult(
          quantity: cans.toDouble(),
          unit: 'Dose',
          name: name,
          note: 'à 400 g',
        );
      }
    }

    if (n.contains('hackfleisch') && unit == 'g') {
      const double packSize = 500;
      if (quantity >= 300) {
        final int packs = (quantity / packSize).round().clamp(1, 999);
        return _PackagingResult(
          quantity: packs.toDouble(),
          unit: 'Packung',
          name: name,
          note: 'à 500 g',
        );
      }
    }

    if (n.contains('milch') && unit == 'ml') {
      final double liters = quantity / 1000;
      if (liters >= 0.5) {
        return _PackagingResult(
          quantity: liters,
          unit: 'l',
          name: name,
          note: note,
        );
      }
    }

    if (n.contains('sahne') && unit == 'ml') {
      const double cupSize = 200;
      if (quantity >= 150) {
        final int cups = (quantity / cupSize).round().clamp(1, 999);
        return _PackagingResult(
          quantity: cups.toDouble(),
          unit: 'Becher',
          name: name,
          note: 'à 200 ml',
        );
      }
    }

    return _PackagingResult(
      quantity: quantity,
      unit: unit,
      name: name,
      note: note,
    );
  }

  static String _pluralizeUnit({
    required String unit,
    required double quantity,
  }) {
    final bool singular = quantity == 1;

    switch (unit) {
      case 'Dose':
        return singular ? 'Dose' : 'Dosen';
      case 'Packung':
        return singular ? 'Packung' : 'Packungen';
      case 'Becher':
        return 'Becher';
      case 'Stk.':
        return 'Stk.';
      case 'Bund':
        return 'Bund';
      default:
        return unit;
    }
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

    name = name.replaceAll(RegExp(r'\blasagneplatte\s+n\b'), 'lasagneplatten');
    name = name.replaceAll(RegExp(r'\bzwiebel\s+n\b'), 'zwiebeln');
    name = name.replaceAll(RegExp(r'\bknoblauchzehe\s+n\b'), 'knoblauchzehen');
    name = name.replaceAll(RegExp(r'\bkarotte\s+n\b'), 'karotten');
    name = name.replaceAll(RegExp(r'\bmöhre\s+n\b'), 'möhren');
    name = name.replaceAll(RegExp(r'\btomate\s+n\b'), 'tomaten');
    name = name.replaceAll(RegExp(r'\bpaprikaschote\s+n\b'), 'paprika');
    name = name.replaceAll(RegExp(r'\bkartoffel\s+n\b'), 'kartoffeln');
    name = name.replaceAll(RegExp(r'\bsuppenhuh\s+n\b'), 'suppenhuhn');

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

    if (name == 'ei er' || name == 'eier') {
      name = 'eier';
    }
    if (name == 'gelbe') {
      name = 'gelbe paprika';
    }
    if (name == 'rote') {
      name = 'rote paprika';
    }
    if (name == 'geschälte' || name == 'geschalte') {
      name = 'geschälte tomaten';
    }
    if (name == 'suppenhuh' || name == 'suppenhuhn') {
      name = 'suppenhuhn';
    }
    if (name == 'sojasausse' || name == 'sojasause') {
      name = 'sojasoße';
    }

    if (name.contains('kartoffel') && name.contains('festkochend')) {
      name = quantity == 1
          ? 'festkochende kartoffel'
          : 'festkochende kartoffeln';
    }

    if (name.contains('gelbe') && !name.contains('paprika')) {
      name = 'gelbe paprika';
    }
    if (name.contains('rote') && !name.contains('paprika')) {
      name = 'rote paprika';
    }

    name = _normalizeWhitespace(name);

    final String? exact = _exactCorrections[name];
    if (exact != null) {
      return IngredientInterpretation(
        name: _applySingularPluralIfNeeded(
          name: exact,
          rawUnit: rawUnit,
          quantity: quantity,
        ),
        displayQuantity: quantity,
        unit: _mapUnit(rawUnit),
        note: note,
      );
    }

    if (_containsAny(name, const <String>[
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

    if (name.contains('sojasoße') || name.contains('sojasauce')) {
      return IngredientInterpretation(
        name: 'Sojasoße',
        displayQuantity: quantity,
        unit: _mapUnit(rawUnit).isEmpty ? 'ml' : _mapUnit(rawUnit),
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

    if (name.contains('kartoffel')) {
      final String displayName = quantity == 1
          ? 'festkochende Kartoffel'
          : 'festkochende Kartoffeln';
      return IngredientInterpretation(
        name: displayName,
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
        unit: _preferPieceLikeUnit(rawUnit, fallback: 'Stk.'),
        note: note,
      );
    }

    if (name.contains('knoblauch')) {
      final String displayName =
          quantity == 1 ? 'Knoblauchzehe' : 'Knoblauchzehen';
      return IngredientInterpretation(
        name: displayName,
        displayQuantity: quantity,
        unit: _preferPieceLikeUnit(rawUnit, fallback: 'Stk.'),
        note: note,
      );
    }

    if (name.contains('karotte') || name.contains('möhre')) {
      final String displayName = quantity == 1 ? 'Karotte' : 'Karotten';
      return IngredientInterpretation(
        name: displayName,
        displayQuantity: quantity,
        unit: _preferPieceLikeUnit(rawUnit, fallback: 'Stk.'),
        note: note,
      );
    }

    if (name.contains('ei')) {
      final String displayName = quantity == 1 ? 'Ei' : 'Eier';
      return IngredientInterpretation(
        name: displayName,
        displayQuantity: quantity,
        unit: '',
        note: note,
      );
    }

    if (name.contains('suppenhuhn')) {
      return IngredientInterpretation(
        name: 'Suppenhuhn',
        displayQuantity: quantity,
        unit: _preferPieceLikeUnit(rawUnit, fallback: 'Stk.'),
        note: note,
      );
    }

    if (name.contains('gelbe paprika')) {
      return IngredientInterpretation(
        name: 'gelbe Paprika',
        displayQuantity: quantity,
        unit: _preferPieceLikeUnit(rawUnit, fallback: 'Stk.'),
        note: note,
      );
    }

    if (name.contains('rote paprika')) {
      return IngredientInterpretation(
        name: 'rote Paprika',
        displayQuantity: quantity,
        unit: _preferPieceLikeUnit(rawUnit, fallback: 'Stk.'),
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

    if (name.contains('joghurt')) {
      return IngredientInterpretation(
        name: 'Joghurt',
        displayQuantity: quantity,
        unit: _fallbackUnit(_mapUnit(rawUnit), 'g'),
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

    final String fallbackName = _applySingularPluralIfNeeded(
      name: _titleCaseGerman(name)
          .replaceFirst('Rote Paprika', 'rote Paprika')
          .replaceFirst('Gelbe Paprika', 'gelbe Paprika')
          .replaceFirst('Grüne Paprika', 'grüne Paprika')
          .replaceFirst('Festkochende Kartoffel', 'festkochende Kartoffel')
          .replaceFirst('Festkochende Kartoffeln', 'festkochende Kartoffeln'),
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

  static String _applySingularPluralIfNeeded({
    required String name,
    required String rawUnit,
    required double quantity,
  }) {
    final String mapped = _mapUnit(rawUnit);

    if ((mapped == 'Stk.' || mapped.isEmpty) && quantity == 1) {
      if (name == 'Zwiebeln') return 'Zwiebel';
      if (name == 'Knoblauchzehen') return 'Knoblauchzehe';
      if (name == 'Karotten') return 'Karotte';
      if (name == 'Eier') return 'Ei';
    }

    if ((mapped == 'Stk.' || mapped.isEmpty) && quantity > 1) {
      if (name == 'Zwiebel') return 'Zwiebeln';
      if (name == 'Knoblauchzehe') return 'Knoblauchzehen';
      if (name == 'Karotte') return 'Karotten';
      if (name == 'Ei') return 'Eier';
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
    'rote zwiebel': 'rote Zwiebel',
    'rote zwiebeln': 'rote Zwiebeln',
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
    'rote paprika': 'rote Paprika',
    'gelbe paprika': 'gelbe Paprika',
    'grüne paprika': 'grüne Paprika',
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
    'festkochende kartoffel': 'festkochende Kartoffel',
    'festkochende kartoffeln': 'festkochende Kartoffeln',
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
    'sojasoße': 'Sojasoße',
    'sojasauce': 'Sojasoße',
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
    'suppenhuhn': 'Suppenhuhn',
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
    'gelbe paprika': 'gelbe Paprika',
    'rote paprika': 'rote Paprika',
  };
}

class _PackagingResult {
  final double quantity;
  final String unit;
  final String name;
  final String? note;

  const _PackagingResult({
    required this.quantity,
    required this.unit,
    required this.name,
    this.note,
  });
}

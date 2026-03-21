import 'ingredient_formatter.dart';
import 'purchasable_item.dart';

class PurchasableItemMapper {
  static PurchasableItem fromIngredient({
    required double quantity,
    required String unit,
    required String name,
  }) {
    final IngredientInterpretation parsed =
        IngredientParser.parse(name, quantity, unit);

    final String normalizedName = parsed.name;
    final String lower = normalizedName.toLowerCase();
    final String effectiveUnit =
        (parsed.unit == null || parsed.unit!.isEmpty)
            ? _inferFallbackUnit(lower)
            : parsed.unit!;

    return PurchasableItem(
      displayName: normalizedName,
      category: _categoryFor(lower),
      shopSearchQuery: _shopSearchQuery(
        lower: lower,
        name: normalizedName,
        quantity: parsed.displayQuantity,
        unit: effectiveUnit,
      ),
      quantity: parsed.displayQuantity,
      unit: effectiveUnit,
      preferredPackage: _preferredPackage(lower, effectiveUnit),
      note: parsed.note,
    );
  }

  static PurchasableCategory _categoryFor(String lower) {
    // Wichtig: speziellere Kategorien zuerst

    if (_containsAny(lower, const <String>[
      'geschälte tomaten',
      'gehackte tomaten',
      'passierte tomaten',
      'stückige tomaten',
      'tomatenmark',
      'ketchup',
      'kokosmilch',
      'thunfisch',
      'kichererbsen',
      'kidneybohnen',
      'weiße bohnen',
    ])) {
      return PurchasableCategory.konserven;
    }

    if (_containsAny(lower, const <String>[
      'hackfleisch',
      'rinderhack',
      'hähnchen',
      'speck',
      'schinken',
      'suppenhuhn',
    ])) {
      return PurchasableCategory.fleisch;
    }

    if (_containsAny(lower, const <String>[
      'lachs',
      'thunfisch',
    ])) {
      return PurchasableCategory.fisch;
    }

    if (_containsAny(lower, const <String>[
      'milch',
      'sahne',
      'joghurt',
      'quark',
      'frischkäse',
      'schmand',
      'mascarpone',
      'ricotta',
      'mozzarella',
      'parmesan',
      'gouda',
      'emmentaler',
      'feta',
      'butter',
    ])) {
      return PurchasableCategory.milchprodukte;
    }

    if (_containsAny(lower, const <String>[
      'spaghetti',
      'nudeln',
      'penne',
      'reis',
      'basmatireis',
      'lasagneplatten',
      'mehl',
      'zucker',
      'hefe',
      'backpulver',
      'natron',
    ])) {
      return PurchasableCategory.trockenwaren;
    }

    if (_containsAny(lower, const <String>[
      'salz',
      'pfeffer',
      'zimt',
      'muskat',
      'paprikapulver',
      'currypulver',
      'oregano',
      'thymian',
      'rosmarin',
      'sojasoße',
      'sojasauce',
      'olivenöl',
      'öl',
      'essig',
      'balsamico',
      'honig',
      'senf',
      'brühe',
    ])) {
      return PurchasableCategory.gewuerze;
    }

    if (_containsAny(lower, const <String>[
      'zwiebel',
      'knoblauch',
      'karotte',
      'möhre',
      'kartoffel',
      'paprika',
      'zucchini',
      'aubergine',
      'brokkoli',
      'blumenkohl',
      'spinat',
      'gurke',
      'tomate',
      'tomaten',
      'lauch',
      'porree',
      'ingwer',
      'chili',
      'mais',
      'erbsen',
      'linsen',
      'kichererbsen',
      'bohnen',
      'petersilie',
      'schnittlauch',
      'basilikum',
    ])) {
      return PurchasableCategory.gemuese;
    }

    return PurchasableCategory.sonstiges;
  }

  static String _shopSearchQuery({
    required String lower,
    required String name,
    required double quantity,
    required String unit,
  }) {
    if (lower.contains('stückige tomaten') ||
        lower.contains('gehackte tomaten') ||
        lower.contains('geschälte tomaten')) {
      return '$lower 400g';
    }

    if (lower.contains('hackfleisch')) {
      return '$lower 500g';
    }

    if (lower.contains('sahne')) {
      return '$lower 200ml';
    }

    if (lower.contains('milch')) {
      return '$lower 1l';
    }

    return name.toLowerCase();
  }

  static String? _preferredPackage(String lower, String unit) {
    if (lower.contains('tomaten')) return 'Dose 400 g';
    if (lower.contains('hackfleisch')) return 'Packung 500 g';
    if (lower.contains('sahne')) return 'Becher 200 ml';
    if (lower.contains('milch')) return '1 l';
    if (unit == 'Bund') return 'Bund';
    return null;
  }

  static String _inferFallbackUnit(String lower) {
    if (lower.contains('milch') || lower.contains('sahne')) return 'ml';

    if (lower.contains('joghurt') ||
        lower.contains('quark') ||
        lower.contains('hackfleisch') ||
        lower.contains('tomaten') ||
        lower.contains('mehl') ||
        lower.contains('reis') ||
        lower.contains('spaghetti') ||
        lower.contains('nudeln')) {
      return 'g';
    }

    return '';
  }

  static bool _containsAny(String text, List<String> needles) {
    for (final String needle in needles) {
      if (text.contains(needle)) return true;
    }
    return false;
  }
}

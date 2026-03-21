import 'coop_product_preferences.dart';
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

    final String canonicalKey =
        IngredientFormatter.canonicalMergeName(normalizedName);

    final CoopProductPreference? preference =
        CoopProductPreferences.findByCanonicalKey(canonicalKey);

    return PurchasableItem(
      displayName: normalizedName,
      category: _categoryFor(lower),
      shopSearchQuery: _shopSearchQuery(
        lower: lower,
        name: normalizedName,
        quantity: parsed.displayQuantity,
        unit: effectiveUnit,
      ),
      coopSearchQuery: _coopSearchQuery(
        lower: lower,
        name: normalizedName,
        quantity: parsed.displayQuantity,
        unit: effectiveUnit,
      ),
      coopPreferredSearchQuery: preference?.preferredSearchQuery,
      coopPreferredProductLabel: preference?.preferredProductLabel,
      quantity: parsed.displayQuantity,
      unit: effectiveUnit,
      preferredPackage: _preferredPackage(lower, effectiveUnit),
      purchaseHeuristic: _purchaseHeuristic(
        lower: lower,
        quantity: parsed.displayQuantity,
        unit: effectiveUnit,
      ),
      note: parsed.note,
    );
  }

  static PurchasableCategory _categoryFor(String lower) {
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

    if (lower.contains('joghurt')) {
      return '$lower 500g';
    }

    return name.toLowerCase();
  }

  static String _coopSearchQuery({
    required String lower,
    required String name,
    required double quantity,
    required String unit,
  }) {
    if (lower.contains('stückige tomaten')) {
      return 'stückige tomaten 400g';
    }

    if (lower.contains('gehackte tomaten')) {
      return 'gehackte tomaten 400g';
    }

    if (lower.contains('geschälte tomaten')) {
      return 'geschälte tomaten 400g';
    }

    if (lower.contains('passierte tomaten')) {
      return 'passierte tomaten 500g';
    }

    if (lower.contains('hackfleisch')) {
      return 'hackfleisch gemischt 500g';
    }

    if (lower.contains('milch')) {
      return 'milch 1l';
    }

    if (lower.contains('sahne')) {
      return 'rahm 200ml';
    }

    if (lower.contains('joghurt')) {
      return 'nature joghurt 500g';
    }

    if (lower.contains('parmesan')) {
      return 'parmesan gerieben';
    }

    if (lower.contains('mozzarella')) {
      return 'mozzarella';
    }

    if (lower.contains('sojasoße') || lower.contains('sojasauce')) {
      return 'sojasauce';
    }

    if (lower.contains('festkochende kartoffeln') ||
        lower.contains('kartoffel')) {
      return 'kartoffeln festkochend';
    }

    if (lower.contains('rote paprika')) {
      return 'paprika rot';
    }

    if (lower.contains('gelbe paprika')) {
      return 'paprika gelb';
    }

    return name.toLowerCase();
  }

  static String? _preferredPackage(String lower, String unit) {
    if (lower.contains('tomaten')) return 'Dose 400 g';
    if (lower.contains('hackfleisch')) return 'Packung 500 g';
    if (lower.contains('sahne')) return 'Becher 200 ml';
    if (lower.contains('milch')) return '1 l';
    if (lower.contains('joghurt')) return 'Becher 500 g';
    if (unit == 'Bund') return 'Bund';
    return null;
  }

  static String? _purchaseHeuristic({
    required String lower,
    required double quantity,
    required String unit,
  }) {
    if (lower.contains('tomaten')) {
      return 'Bevorzuge Standard-Dosen statt Einzelgewichten.';
    }

    if (lower.contains('hackfleisch')) {
      return 'Bevorzuge 500-g-Packungen und runde eher nach oben.';
    }

    if (lower.contains('milch')) {
      return 'Bevorzuge 1-Liter-Packungen.';
    }

    if (lower.contains('sahne')) {
      return 'Bevorzuge 200-ml-Becher.';
    }

    if (lower.contains('joghurt')) {
      return 'Bevorzuge Naturjoghurt in Bechern statt Spezialsorten.';
    }

    if (unit == 'Bund') {
      return 'Kräuter möglichst als ganzen Bund kaufen.';
    }

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

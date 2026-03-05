import 'category_de.dart';

class CategoryClassifierDe {
  static CategoryDe classify(String normalizedName) {
    final s = normalizedName.toLowerCase();

    bool hasAny(List<String> kws) => kws.any(s.contains);

    if (hasAny([
      'zwiebel',
      'knoblauch',
      'tomate',
      'paprika',
      'karotte',
      'möhre',
      'moehre',
      'salat',
      'gurke',
      'brokkoli',
      'spinat',
    ])) {
      return CategoryDe.gemuese;
    }

    if (hasAny(['apfel', 'banane', 'zitrone', 'orange', 'beere', 'birne'])) {
      return CategoryDe.obst;
    }

    if (hasAny([
      'milch',
      'joghurt',
      'quark',
      'käse',
      'kaese',
      'butter',
      'sahne',
      'mozzarella',
    ])) {
      return CategoryDe.milchprodukte;
    }

    if (hasAny([
      'hähnchen',
      'haehnchen',
      'rind',
      'schwein',
      'lachs',
      'thunfisch',
      'fisch',
    ])) {
      return CategoryDe.fleischFisch;
    }

    if (hasAny([
      'reis',
      'nudel',
      'pasta',
      'linsen',
      'bohnen',
      'mehl',
      'zucker',
      'hafer',
      'couscous',
    ])) {
      return CategoryDe.trockenwaren;
    }

    if (hasAny(['backpulver', 'hefe', 'vanille', 'kakao'])) {
      return CategoryDe.backen;
    }

    if (hasAny([
      'salz',
      'pfeffer',
      'chili',
      'curry',
      'kreuzkümmel',
      'kreuzkuemmel',
      'zimt',
      'muskat',
    ])) {
      return CategoryDe.gewuerze;
    }

    if (hasAny([
      'öl',
      'oel',
      'olivenöl',
      'olivenoel',
      'essig',
      'sojasauce',
      'sauce',
      'senf',
      'ketchup',
    ])) {
      return CategoryDe.oeleSaucen;
    }

    if (hasAny(['dose', 'konserve', 'tomatenmark'])) {
      return CategoryDe.konserven;
    }

    if (hasAny(['tiefkühl', 'tiefkuehl', 'gefroren'])) {
      return CategoryDe.tiefkuehl;
    }

    if (hasAny(['wasser', 'saft', 'bier', 'wein'])) {
      return CategoryDe.getraenke;
    }

    return CategoryDe.sonstiges;
  }
}

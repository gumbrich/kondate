import 'dart:math' as math;

/// Small, local culinary vocabulary, extended with the user's saved recipe
/// titles. These are spelling suggestions, not translation or automatic edits.
class MealSpelling {
  static const words = '''
Zitronenrisotto Risotto Zitronen Zitrone Zitronensaft Zitronenschale Reis
Risottoreis Gemüse Gemüseauflauf Auflauf Kartoffeln Kartoffel Kartoffelgratin
Härdöpfel Härdöpfelauflauf Herdöpfel Herdöpfelauflauf Wirz Wirsing Feta
Rüebli Rüeblisuppe Ruebli Zwiebel Zwiebeln Knoblauch Lauch Lauchsuppe
Rahm Vollrahm Halbrahm Sahne Creme Crème Butter Milch Joghurt Jogurt Quark
Käse Gruyère Emmentaler Parmesan Mozzarella Ricotta Gorgonzola Halloumi
Tomate Tomaten Tomatensauce Tomatensuppe Sauce Sosse Soße Sugo Pesto
Pasta Spaghetti Bolognese Carbonara Lasagne Penne Fusilli Nudeln Nüdeli
Fondue Raclette Rösti Roesti Röschti Geschnetzeltes Zürcher Zuercher
Poulet Pouletbrust Pouletschenkel Hähnchen Hühnerbrust Huhn Chicken
Fleisch Rindfleisch Rindsfleisch Hackfleisch Rind Schwein Schweinefilet
Fisch Lachs Forelle Thunfisch Garnelen Crevetten Garnelencurry
Salat Blattsalat Gurke Gurken Peperoni Paprika Zucchetti Zucchini
Aubergine Auberginen Kürbis Kürbissuppe Kuerbis Brokkoli Blumenkohl Spinat
Champignons Pilze Pilzrisotto Pilzsuppe Sellerie Fenchel Erbsen Bohnen
Linsen Linsensuppe Kichererbsen Hummus Tofu Tempeh Seitan Kokosmilch
Curry Currypaste Kokoscurry Chili Reisnudeln Ramen Udon Soba Sushi
Brot Brötchen Brötli Broetli Zopf Toast Pizza Burger Pommes Ofengemüse
Ei Eier Omelette Rührei Spiegelei Pfannkuchen Pancakes Crêpes Waffeln
Haferflocken Porridge Müesli Müsli Birchermüesli Muesli Früchte Beeren
Apfel Äpfel Birne Banane Bananen Orange Orangen Zimt Honig Nüsse Mandeln
Basilikum Petersilie Schnittlauch Koriander Rosmarin Thymian Oregano
Salz Pfeffer Olivenöl Rapsöl Essig Brühe Bouillon Gemüsebouillon
lemon lemons rice potatoes potato cabbage savoy feta cheese cream milk
butter yogurt yoghurt onion onions garlic leek leeks carrots carrot
tomato tomatoes spinach mushroom mushrooms broccoli cauliflower pumpkin
peas beans lentils chickpeas beef pork chicken salmon fish tuna prawns
shrimp eggs egg bread noodles soup stew casserole gratin salad dressing
roasted baked grilled mashed stuffed fried scrambled steamed vegetables
vegetable roast stir fry curry lentil coconut pepper peppers sweet sour
oats oatmeal porridge berries apple apples pear pears banana cinnamon
nut nuts almond almonds parsley basil coriander olive oil vinegar stock
mit und oder ohne vom von für im in aus zum zur bei der die das
with and or without of for in on a an the de du al alla au
''';

  static final _tokens = RegExp(r'[A-Za-zÀ-ÖØ-öø-ÿ]+');

  static String _key(String value) => value
      .toLowerCase()
      .replaceAll('ä', 'a')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('é', 'e')
      .replaceAll('è', 'e')
      .replaceAll('ê', 'e')
      .replaceAll('ß', 'ss');

  static final Map<String, String> _baseVocabulary = (() {
    final result = <String, String>{};
    for (final match in _tokens.allMatches(words)) {
      final word = match.group(0)!;
      result.putIfAbsent(_key(word), () => word);
    }
    return result;
  })();

  static List<String> suggestions(
    String text, {
    Iterable<String> knownPhrases = const [],
  }) {
    final vocabulary = Map<String, String>.of(_baseVocabulary);
    for (final match in _tokens.allMatches(knownPhrases.join(' '))) {
      final word = match.group(0)!;
      vocabulary.putIfAbsent(_key(word), () => word);
    }
    var variants = <String>[''];
    var offset = 0;
    for (final token in _tokens.allMatches(text)) {
      final word = token.group(0)!;
      final key = _key(word);
      final choices = <String>[];
      if (key.length >= 4 && !vocabulary.containsKey(key)) {
        final limit = key.length >= 12
            ? 3
            : key.length >= 7
            ? 2
            : 1;
        var best = limit + 1;
        for (final entry in vocabulary.entries) {
          if ((key.length - entry.key.length).abs() > limit ||
              entry.key.length < 4) {
            continue;
          }
          final distance = _distance(key, entry.key);
          if (distance > limit ||
              distance / math.max(key.length, entry.key.length) > 0.26) {
            continue;
          }
          if (distance < best) {
            choices.clear();
            best = distance;
          }
          if (distance == best && choices.length < 3) choices.add(entry.value);
        }
      }
      final separator = text.substring(offset, token.start);
      variants = [
        for (final prefix in variants)
          for (final choice in choices.isEmpty ? [word] : choices)
            '$prefix$separator$choice',
      ].take(3).toList();
      offset = token.end;
    }
    return variants
        .map((v) => '$v${text.substring(offset)}')
        .where((v) => v != text)
        .toSet()
        .toList();
  }

  static int _distance(String a, String b) {
    final rows = List.generate(
      a.length + 1,
      (_) => List.filled(b.length + 1, 0),
    );
    for (var i = 0; i <= a.length; i++) {
      rows[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      rows[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        rows[i][j] = math.min(
          math.min(rows[i - 1][j] + 1, rows[i][j - 1] + 1),
          rows[i - 1][j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1),
        );
        if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) {
          rows[i][j] = math.min(rows[i][j], rows[i - 2][j - 2] + 1);
        }
      }
    }
    return rows[a.length][b.length];
  }
}

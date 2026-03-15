import '../model/parsed_recipe.dart';
import 'jsonld_extractor.dart';

class JsonLdRecipeParser {
  final JsonLdExtractor extractor;

  JsonLdRecipeParser({JsonLdExtractor? extractor})
      : extractor = extractor ?? JsonLdExtractor();

  ParsedRecipe parseFromHtml(String html) {
    final List<dynamic> blobs = extractor.extractJsonLdObjects(html);
    final Map<String, dynamic>? obj = extractor.findRecipeObject(blobs);

    if (obj == null) {
      throw Exception('No JSON-LD Recipe found.');
    }

    final String? title = _readTitle(obj);
    if (title == null || title.isEmpty) {
      throw Exception('Recipe name missing.');
    }

    final List<String> ingredients = _readIngredients(obj);
    if (ingredients.isEmpty) {
      throw Exception('Recipe ingredients missing.');
    }

    final double? servings = _parseServings(obj['recipeYield']);

    return ParsedRecipe(
      title: title,
      servings: servings,
      ingredientLines: ingredients,
    );
  }

  String? _readTitle(Map<String, dynamic> obj) {
    final dynamic name = obj['name'];

    if (name is String) {
      final String value = name.trim();
      return value.isEmpty ? null : value;
    }

    return null;
  }

  List<String> _readIngredients(Map<String, dynamic> obj) {
    final dynamic rawIngredients = obj['recipeIngredient'];

    if (rawIngredients is List) {
      return rawIngredients
          .map((dynamic item) => item?.toString().trim() ?? '')
          .where((String s) => s.isNotEmpty)
          .toList();
    }

    return const <String>[];
  }

  double? _parseServings(dynamic recipeYield) {
    String? s;

    if (recipeYield is String) {
      s = recipeYield;
    } else if (recipeYield is num) {
      return recipeYield.toDouble();
    } else if (recipeYield is List && recipeYield.isNotEmpty) {
      final dynamic first = recipeYield.first;
      if (first is String) {
        s = first;
      } else if (first is num) {
        return first.toDouble();
      }
    }

    if (s == null) return null;

    final RegExpMatch? m = RegExp(r'(\d+([.,]\d+)?)').firstMatch(s);
    if (m == null) return null;

    return double.tryParse(m.group(1)!.replaceAll(',', '.'));
  }
}

import '../model/parsed_recipe.dart';
import 'jsonld_extractor.dart';

class JsonLdRecipeParser {
  final JsonLdExtractor extractor;

  JsonLdRecipeParser({JsonLdExtractor? extractor})
      : extractor = extractor ?? JsonLdExtractor();

  ParsedRecipe parseFromHtml(String html) {
    final blobs = extractor.extractJsonLdObjects(html);
    final obj = extractor.findRecipeObject(blobs);
    if (obj == null) {
      throw Exception('No JSON-LD Recipe found.');
    }

    final title = (obj['name'] as String?)?.trim();
    if (title == null || title.isEmpty) {
      throw Exception('Recipe name missing.');
    }

    final ingredients = (obj['recipeIngredient'] as List?)
            ?.whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList() ??
        const <String>[];

    final servings = _parseServings(obj['recipeYield']);

    return ParsedRecipe(
      title: title,
      servings: servings,
      ingredientLines: ingredients,
    );
  }

  double? _parseServings(dynamic recipeYield) {
    String? s;
    if (recipeYield is String) s = recipeYield;
    if (recipeYield is List &&
        recipeYield.isNotEmpty &&
        recipeYield.first is String) {
      s = recipeYield.first as String;
    }
    if (s == null) return null;

    final m = RegExp(r'(\d+([.,]\d+)?)').firstMatch(s);
    if (m == null) return null;
    return double.tryParse(m.group(1)!.replaceAll(',', '.'));
  }
}

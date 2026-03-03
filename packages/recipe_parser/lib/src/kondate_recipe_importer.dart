import 'package:core/core.dart';

import 'http/page_fetcher.dart';
import 'jsonld/jsonld_recipe_parser.dart';

class KondateRecipeImporter {
  final PageFetcher fetcher;
  final JsonLdRecipeParser parser;

  KondateRecipeImporter({PageFetcher? fetcher, JsonLdRecipeParser? parser})
      : fetcher = fetcher ?? PageFetcher(),
        parser = parser ?? JsonLdRecipeParser();

  Future<Recipe> importRecipe({
    required Uri url,
    required String id,
  }) async {
    final html = await fetcher.fetchHtml(url);
    final parsed = parser.parseFromHtml(html);

    final ingredientLines = parsed.ingredientLines.map((raw) {
      final q = QuantityParserDe.parseLeadingQuantity(raw);
      return IngredientLine(raw: raw, quantity: q, normalizedName: null);
    }).toList();

    return Recipe(
      id: id,
      title: parsed.title,
      sourceUrl: url,
      defaultServings: parsed.servings,
      ingredients: ingredientLines,
    );
  }
}

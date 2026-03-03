import 'ingredient_line.dart';

class Recipe {
  final String id;
  final String title;
  final Uri sourceUrl;
  final double? defaultServings;
  final List<IngredientLine> ingredients;

  const Recipe({
    required this.id,
    required this.title,
    required this.sourceUrl,
    required this.defaultServings,
    required this.ingredients,
  });
}

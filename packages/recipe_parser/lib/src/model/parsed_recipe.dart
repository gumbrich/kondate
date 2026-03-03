class ParsedRecipe {
  final String title;
  final double? servings;
  final List<String> ingredientLines;

  const ParsedRecipe({
    required this.title,
    required this.servings,
    required this.ingredientLines,
  });
}

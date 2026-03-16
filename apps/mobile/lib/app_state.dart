import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KondateAppState {
  final List<Recipe> recipes;
  final MealPlanWeek mealPlan;
  final double targetServings;
  final List<String> trustedSites;
  final int topN;

  const KondateAppState({
    required this.recipes,
    required this.mealPlan,
    required this.targetServings,
    required this.trustedSites,
    required this.topN,
  });

  static const String _recipesKey = 'kondate_recipes_json';
  static const String _mealPlanKey = 'kondate_meal_plan_json';
  static const String _targetServingsKey = 'kondate_target_servings';
  static const String _trustedSitesKey = 'kondate_trusted_sites';
  static const String _topNKey = 'kondate_top_n';

  static KondateAppState initial() {
    return const KondateAppState(
      recipes: <Recipe>[],
      mealPlan: MealPlanWeek(entries: <MealPlanEntry>[]),
      targetServings: 2.5,
      trustedSites: <String>[
        'chefkoch.de',
        'springlane.de',
        'eatsmarter.de',
      ],
      topN: 3,
    );
  }

  static Future<KondateAppState> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String? recipesJson = prefs.getString(_recipesKey);
    final String? mealPlanJson = prefs.getString(_mealPlanKey);
    final double targetServings =
        prefs.getDouble(_targetServingsKey) ?? initial().targetServings;
    final List<String> trustedSites =
        prefs.getStringList(_trustedSitesKey) ?? initial().trustedSites;
    final int topN = prefs.getInt(_topNKey) ?? initial().topN;

    List<Recipe> recipes = <Recipe>[];
    if (recipesJson != null && recipesJson.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(recipesJson) as List<dynamic>;
      recipes = decoded
          .map((dynamic e) => _recipeFromMap(e as Map<String, dynamic>))
          .toList();
    }

    MealPlanWeek mealPlan = const MealPlanWeek(entries: <MealPlanEntry>[]);
    if (mealPlanJson != null && mealPlanJson.isNotEmpty) {
      final Map<String, dynamic> decoded =
          jsonDecode(mealPlanJson) as Map<String, dynamic>;
      mealPlan = _mealPlanFromMap(decoded);
    }

    return KondateAppState(
      recipes: recipes,
      mealPlan: mealPlan,
      targetServings: targetServings,
      trustedSites: trustedSites,
      topN: topN,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'recipes': recipes.map((Recipe r) => _recipeToMap(r)).toList(),
      'mealPlan': _mealPlanToMap(mealPlan),
      'targetServings': targetServings,
      'trustedSites': trustedSites,
      'topN': topN,
    };
  }

  static KondateAppState fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawRecipes =
        (map['recipes'] as List<dynamic>? ?? const <dynamic>[]);
    final List<Recipe> recipes = rawRecipes
        .map((dynamic e) => _recipeFromMap(e as Map<String, dynamic>))
        .toList();

    final Map<String, dynamic> rawMealPlan =
        (map['mealPlan'] as Map<String, dynamic>? ??
            <String, dynamic>{'entries': <dynamic>[]});

    return KondateAppState(
      recipes: recipes,
      mealPlan: _mealPlanFromMap(rawMealPlan),
      targetServings: (map['targetServings'] as num?)?.toDouble() ?? 2.5,
      trustedSites: (map['trustedSites'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(),
      topN: (map['topN'] as num?)?.toInt() ?? 3,
    );
  }

  Future<void> saveAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _recipesKey,
      jsonEncode(
        recipes.map((Recipe r) => _recipeToMap(r)).toList(),
      ),
    );
    await prefs.setString(
      _mealPlanKey,
      jsonEncode(_mealPlanToMap(mealPlan)),
    );
    await prefs.setDouble(_targetServingsKey, targetServings);
    await prefs.setStringList(_trustedSitesKey, trustedSites);
    await prefs.setInt(_topNKey, topN);
  }

  KondateAppState addRecipe(Recipe recipe) {
    return KondateAppState(
      recipes: <Recipe>[...recipes, recipe],
      mealPlan: mealPlan,
      targetServings: targetServings,
      trustedSites: trustedSites,
      topN: topN,
    );
  }

  KondateAppState removeRecipeAt(int index) {
    final List<Recipe> next = <Recipe>[...recipes]..removeAt(index);
    return KondateAppState(
      recipes: next,
      mealPlan: mealPlan,
      targetServings: targetServings,
      trustedSites: trustedSites,
      topN: topN,
    );
  }

  KondateAppState clearRecipes() {
    return KondateAppState(
      recipes: const <Recipe>[],
      mealPlan: mealPlan,
      targetServings: targetServings,
      trustedSites: trustedSites,
      topN: topN,
    );
  }

  KondateAppState incrementServings() {
    return KondateAppState(
      recipes: recipes,
      mealPlan: mealPlan,
      targetServings: targetServings + 0.5,
      trustedSites: trustedSites,
      topN: topN,
    );
  }

  KondateAppState decrementServings() {
    final double next = targetServings > 0.5 ? targetServings - 0.5 : 0.5;
    return KondateAppState(
      recipes: recipes,
      mealPlan: mealPlan,
      targetServings: next,
      trustedSites: trustedSites,
      topN: topN,
    );
  }

  KondateAppState incrementTopN() {
    return KondateAppState(
      recipes: recipes,
      mealPlan: mealPlan,
      targetServings: targetServings,
      trustedSites: trustedSites,
      topN: topN + 1,
    );
  }

  KondateAppState decrementTopN() {
    final int next = topN > 1 ? topN - 1 : 1;
    return KondateAppState(
      recipes: recipes,
      mealPlan: mealPlan,
      targetServings: targetServings,
      trustedSites: trustedSites,
      topN: next,
    );
  }

  KondateAppState updateTrustedSites({
    required List<String> sites,
    required int topN,
  }) {
    return KondateAppState(
      recipes: recipes,
      mealPlan: mealPlan,
      targetServings: targetServings,
      trustedSites: sites,
      topN: topN,
    );
  }

  KondateAppState updateMealPlanEntry({
    required WeekdayDe weekday,
    required String dishIdea,
    required String? recipeId,
  }) {
    return KondateAppState(
      recipes: recipes,
      mealPlan: mealPlan.upsert(
        MealPlanEntry(
          weekday: weekday,
          dishIdea: dishIdea,
          recipeId: recipeId,
        ),
      ),
      targetServings: targetServings,
      trustedSites: trustedSites,
      topN: topN,
    );
  }

  KondateAppState clearWeekday(WeekdayDe weekday) {
    final List<MealPlanEntry> filtered = mealPlan.entries
        .where((MealPlanEntry entry) => entry.weekday != weekday)
        .toList();

    return KondateAppState(
      recipes: recipes,
      mealPlan: MealPlanWeek(entries: filtered),
      targetServings: targetServings,
      trustedSites: trustedSites,
      topN: topN,
    );
  }

  Recipe? findRecipeById(String id) {
    for (final Recipe recipe in recipes) {
      if (recipe.id == id) return recipe;
    }
    return null;
  }

  List<Recipe> selectedMealPlanRecipes() {
    final List<Recipe> selected = <Recipe>[];

    for (final MealPlanEntry entry in mealPlan.entries) {
      final String? recipeId = entry.recipeId;
      if (recipeId == null) continue;

      final Recipe? recipe = findRecipeById(recipeId);
      if (recipe != null) {
        selected.add(recipe);
      }
    }

    return selected;
  }

  static Future<Recipe> importRecipeFromUrl(String urlText) async {
    final Uri url = Uri.parse(urlText);
    final HttpClient client = HttpClient();

    try {
      final HttpClientRequest request =
          await client.postUrl(Uri.parse('http://127.0.0.1:8000/import'));
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(<String, dynamic>{
          'url': url.toString(),
        }),
      );

      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Backend import failed: $body');
      }

      final Map<String, dynamic> json =
          jsonDecode(body) as Map<String, dynamic>;

      final List<String> ingredientLines =
          (json['ingredientLines'] as List<dynamic>)
              .map((dynamic e) => e.toString())
              .toList();

      final List<IngredientLine> ingredients = ingredientLines.map((String raw) {
        final Quantity? q = QuantityParserDe.parseLeadingQuantity(raw);
        return IngredientLine(
          raw: raw,
          quantity: q,
          normalizedName: null,
        );
      }).toList();

      return Recipe(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: json['title'] as String,
        sourceUrl: url,
        defaultServings: (json['servings'] as num?)?.toDouble(),
        ingredients: ingredients,
      );
    } finally {
      client.close(force: true);
    }
  }

  static Map<String, dynamic> _recipeToMap(Recipe recipe) {
    return <String, dynamic>{
      'id': recipe.id,
      'title': recipe.title,
      'sourceUrl': recipe.sourceUrl.toString(),
      'defaultServings': recipe.defaultServings,
      'ingredients': recipe.ingredients.map(_ingredientToMap).toList(),
    };
  }

  static Recipe _recipeFromMap(Map<String, dynamic> map) {
    final List<dynamic> rawIngredients =
        (map['ingredients'] as List<dynamic>? ?? const <dynamic>[]);

    final List<IngredientLine> ingredients = rawIngredients
        .map((dynamic e) => _ingredientFromMap(e as Map<String, dynamic>))
        .toList();

    return Recipe(
      id: map['id'] as String,
      title: map['title'] as String,
      sourceUrl: Uri.parse(map['sourceUrl'] as String),
      defaultServings: (map['defaultServings'] as num?)?.toDouble(),
      ingredients: ingredients,
    );
  }

  static Map<String, dynamic> _ingredientToMap(IngredientLine line) {
    return <String, dynamic>{
      'raw': line.raw,
      'normalizedName': line.normalizedName,
    };
  }

  static IngredientLine _ingredientFromMap(Map<String, dynamic> map) {
    final String raw = map['raw'] as String;

    return IngredientLine(
      raw: raw,
      quantity: QuantityParserDe.parseLeadingQuantity(raw),
      normalizedName: map['normalizedName'] as String?,
    );
  }

  static Map<String, dynamic> _mealPlanToMap(MealPlanWeek mealPlan) {
    return <String, dynamic>{
      'entries': mealPlan.entries.map(_mealPlanEntryToMap).toList(),
    };
  }

  static MealPlanWeek _mealPlanFromMap(Map<String, dynamic> map) {
    final List<dynamic> rawEntries =
        (map['entries'] as List<dynamic>? ?? const <dynamic>[]);

    return MealPlanWeek(
      entries: rawEntries
          .map((dynamic e) => _mealPlanEntryFromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static Map<String, dynamic> _mealPlanEntryToMap(MealPlanEntry entry) {
    return <String, dynamic>{
      'weekday': entry.weekday.name,
      'dishIdea': entry.dishIdea,
      'recipeId': entry.recipeId,
    };
  }

  static MealPlanEntry _mealPlanEntryFromMap(Map<String, dynamic> map) {
    return MealPlanEntry(
      weekday: WeekdayDe.values.byName(map['weekday'] as String),
      dishIdea: map['dishIdea'] as String?,
      recipeId: map['recipeId'] as String?,
    );
  }
}

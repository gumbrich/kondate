import 'dart:convert';

import 'package:core/core.dart';
import 'package:recipe_parser/recipe_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

class KondateAppState {
  static const String recipesPrefsKey = 'saved_recipes_v1';
  static const String servingsPrefsKey = 'target_servings_v1';
  static const String mealPlanPrefsKey = 'meal_plan_v1';
  static const String trustedSitesPrefsKey = 'trusted_sites_v1';
  static const String topNPrefsKey = 'recipe_top_n_v1';

  static const List<String> defaultTrustedSites = <String>[
    'chefkoch.de',
    'eatsmarter.de',
    'springlane.de',
  ];

  final List<Recipe> recipes;
  final double targetServings;
  final int topN;
  final List<String> trustedSites;
  final MealPlanWeek mealPlan;

  const KondateAppState({
    required this.recipes,
    required this.targetServings,
    required this.topN,
    required this.trustedSites,
    required this.mealPlan,
  });

  factory KondateAppState.initial() {
    return KondateAppState(
      recipes: <Recipe>[],
      targetServings: 2.5,
      topN: 3,
      trustedSites: List<String>.from(defaultTrustedSites),
      mealPlan: MealPlanWeek(
        entries: const <MealPlanEntry>[
          MealPlanEntry(weekday: WeekdayDe.montag),
          MealPlanEntry(weekday: WeekdayDe.dienstag),
          MealPlanEntry(weekday: WeekdayDe.mittwoch),
          MealPlanEntry(weekday: WeekdayDe.donnerstag),
          MealPlanEntry(weekday: WeekdayDe.freitag),
          MealPlanEntry(weekday: WeekdayDe.samstag),
          MealPlanEntry(weekday: WeekdayDe.sonntag),
        ],
      ),
    );
  }

  KondateAppState copyWith({
    List<Recipe>? recipes,
    double? targetServings,
    int? topN,
    List<String>? trustedSites,
    MealPlanWeek? mealPlan,
  }) {
    return KondateAppState(
      recipes: recipes ?? this.recipes,
      targetServings: targetServings ?? this.targetServings,
      topN: topN ?? this.topN,
      trustedSites: trustedSites ?? this.trustedSites,
      mealPlan: mealPlan ?? this.mealPlan,
    );
  }

  static Future<KondateAppState> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    double targetServings = 2.5;
    int topN = 3;
    List<String> trustedSites = List<String>.from(defaultTrustedSites);
    final List<Recipe> recipes = <Recipe>[];
    MealPlanWeek mealPlan = KondateAppState.initial().mealPlan;

    final double? savedServings = prefs.getDouble(servingsPrefsKey);
    if (savedServings != null && savedServings > 0) {
      targetServings = savedServings;
    }

    final int? savedTopN = prefs.getInt(topNPrefsKey);
    if (savedTopN != null && savedTopN > 0) {
      topN = savedTopN;
    }

    final List<String>? savedSites = prefs.getStringList(trustedSitesPrefsKey);
    if (savedSites != null && savedSites.isNotEmpty) {
      trustedSites = savedSites;
    }

    final String? recipesRaw = prefs.getString(recipesPrefsKey);
    if (recipesRaw != null && recipesRaw.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(recipesRaw) as List<dynamic>;
      recipes.addAll(
        decoded
            .whereType<Map<String, dynamic>>()
            .map(_recipeFromJson)
            .toList(),
      );
    }

    final String? mealPlanRaw = prefs.getString(mealPlanPrefsKey);
    if (mealPlanRaw != null && mealPlanRaw.isNotEmpty) {
      final List<dynamic> decoded = jsonDecode(mealPlanRaw) as List<dynamic>;
      final List<MealPlanEntry> entries = decoded
          .whereType<Map<String, dynamic>>()
          .map(_mealPlanEntryFromJson)
          .toList();
      mealPlan = MealPlanWeek(entries: entries);
    }

    return KondateAppState(
      recipes: recipes,
      targetServings: targetServings,
      topN: topN,
      trustedSites: trustedSites,
      mealPlan: mealPlan,
    );
  }

  Future<void> saveAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setDouble(servingsPrefsKey, targetServings);
    await prefs.setInt(topNPrefsKey, topN);
    await prefs.setStringList(trustedSitesPrefsKey, trustedSites);

    final String recipesEncoded =
        jsonEncode(recipes.map(_recipeToJson).toList());
    await prefs.setString(recipesPrefsKey, recipesEncoded);

    final String mealPlanEncoded =
        jsonEncode(mealPlan.entries.map(_mealPlanEntryToJson).toList());
    await prefs.setString(mealPlanPrefsKey, mealPlanEncoded);
  }

  Recipe? findRecipeById(String id) {
    for (final Recipe recipe in recipes) {
      if (recipe.id == id) return recipe;
    }
    return null;
  }

  List<Recipe> selectedMealPlanRecipes() {
    final List<Recipe> result = <Recipe>[];

    for (final MealPlanEntry entry in mealPlan.entries) {
      final String? recipeId = entry.recipeId;
      if (recipeId == null) continue;

      final Recipe? recipe = findRecipeById(recipeId);
      if (recipe != null) {
        result.add(recipe);
      }
    }

    return result;
  }

  KondateAppState incrementServings() {
    return copyWith(targetServings: targetServings + 0.5);
  }

  KondateAppState decrementServings() {
    if (targetServings <= 0.5) return this;
    return copyWith(targetServings: targetServings - 0.5);
  }

  KondateAppState incrementTopN() {
    return copyWith(topN: topN + 1);
  }

  KondateAppState decrementTopN() {
    if (topN <= 1) return this;
    return copyWith(topN: topN - 1);
  }

  KondateAppState addRecipe(Recipe recipe) {
    return copyWith(recipes: <Recipe>[...recipes, recipe]);
  }

  KondateAppState removeRecipeAt(int index) {
    final List<Recipe> updated = List<Recipe>.from(recipes)..removeAt(index);
    return copyWith(recipes: updated);
  }

  KondateAppState clearRecipes() {
    return copyWith(recipes: <Recipe>[]);
  }

  KondateAppState updateTrustedSites({
    required List<String> sites,
    required int topN,
  }) {
    return copyWith(
      trustedSites: sites,
      topN: topN,
    );
  }

  KondateAppState updateMealPlanEntry({
    required WeekdayDe weekday,
    required String dishIdea,
    required String? recipeId,
  }) {
    final MealPlanEntry current =
        mealPlan.entryFor(weekday) ?? MealPlanEntry(weekday: weekday);

    return copyWith(
      mealPlan: mealPlan.upsert(
        current.copyWith(
          dishIdea: dishIdea,
          recipeId: recipeId,
        ),
      ),
    );
  }

  KondateAppState clearWeekday(WeekdayDe weekday) {
    final MealPlanEntry current =
        mealPlan.entryFor(weekday) ?? MealPlanEntry(weekday: weekday);

    return copyWith(
      mealPlan: mealPlan.upsert(
        current.copyWith(
          dishIdea: '',
          recipeId: null,
        ),
      ),
    );
  }

  static Future<Recipe> importRecipeFromUrl(String urlText) async {
    final KondateRecipeImporter importer = KondateRecipeImporter();
    return importer.importRecipe(
      url: Uri.parse(urlText),
      id: DateTime.now().millisecondsSinceEpoch.toString(),
    );
  }

  static Map<String, dynamic> _recipeToJson(Recipe recipe) {
    return <String, dynamic>{
      'id': recipe.id,
      'title': recipe.title,
      'sourceUrl': recipe.sourceUrl.toString(),
      'defaultServings': recipe.defaultServings,
      'ingredients': recipe.ingredients.map(_ingredientLineToJson).toList(),
    };
  }

  static Recipe _recipeFromJson(Map<String, dynamic> json) {
    final List<dynamic> ingredientsRaw =
        json['ingredients'] as List<dynamic>? ?? <dynamic>[];

    return Recipe(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      sourceUrl: Uri.parse(
        json['sourceUrl'] as String? ?? 'https://example.com',
      ),
      defaultServings: (json['defaultServings'] as num?)?.toDouble(),
      ingredients: ingredientsRaw
          .whereType<Map<String, dynamic>>()
          .map(_ingredientLineFromJson)
          .toList(),
    );
  }

  static Map<String, dynamic> _ingredientLineToJson(IngredientLine line) {
    return <String, dynamic>{
      'raw': line.raw,
      'normalizedName': line.normalizedName,
      'quantity': line.quantity == null
          ? null
          : <String, dynamic>{
              'value': line.quantity!.value,
              'unit': line.quantity!.unit.name,
            },
    };
  }

  static IngredientLine _ingredientLineFromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? q = json['quantity'] as Map<String, dynamic>?;

    return IngredientLine(
      raw: json['raw'] as String? ?? '',
      normalizedName: json['normalizedName'] as String?,
      quantity: q == null
          ? null
          : Quantity(
              (q['value'] as num).toDouble(),
              _unitFromName(q['unit'] as String?),
            ),
    );
  }

  static Map<String, dynamic> _mealPlanEntryToJson(MealPlanEntry entry) {
    return <String, dynamic>{
      'weekday': entry.weekday.name,
      'dishIdea': entry.dishIdea,
      'recipeId': entry.recipeId,
    };
  }

  static MealPlanEntry _mealPlanEntryFromJson(Map<String, dynamic> json) {
    return MealPlanEntry(
      weekday: WeekdayDe.values.firstWhere(
        (WeekdayDe d) => d.name == json['weekday'],
        orElse: () => WeekdayDe.montag,
      ),
      dishIdea: json['dishIdea'] as String?,
      recipeId: json['recipeId'] as String?,
    );
  }

  static Unit _unitFromName(String? name) {
    return Unit.values.firstWhere(
      (Unit u) => u.name == name,
      orElse: () => Unit.unknown,
    );
  }
}

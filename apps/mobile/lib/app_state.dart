import 'dart:convert';
import 'dart:io';

import 'package:core/core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'backend_config.dart';

class ShoppingManualItem {
  final String id;
  final String name;
  final bool checked;

  const ShoppingManualItem({
    required this.id,
    required this.name,
    required this.checked,
  });

  ShoppingManualItem copyWith({
    String? id,
    String? name,
    bool? checked,
  }) {
    return ShoppingManualItem(
      id: id ?? this.id,
      name: name ?? this.name,
      checked: checked ?? this.checked,
    );
  }
}

class ShoppingState {
  final List<String> checkedGeneratedItemIds;
  final List<String> removedGeneratedItemIds;
  final List<ShoppingManualItem> manualItems;

  const ShoppingState({
    required this.checkedGeneratedItemIds,
    required this.removedGeneratedItemIds,
    required this.manualItems,
  });

  const ShoppingState.initial()
      : checkedGeneratedItemIds = const <String>[],
        removedGeneratedItemIds = const <String>[],
        manualItems = const <ShoppingManualItem>[];

  ShoppingState toggleGeneratedChecked(String itemId) {
    final Set<String> checked = checkedGeneratedItemIds.toSet();
    if (checked.contains(itemId)) {
      checked.remove(itemId);
    } else {
      checked.add(itemId);
    }
    return ShoppingState(
      checkedGeneratedItemIds: checked.toList(),
      removedGeneratedItemIds: removedGeneratedItemIds,
      manualItems: manualItems,
    );
  }

  ShoppingState toggleGeneratedRemoved(String itemId) {
    final Set<String> removed = removedGeneratedItemIds.toSet();
    if (removed.contains(itemId)) {
      removed.remove(itemId);
    } else {
      removed.add(itemId);
    }
    return ShoppingState(
      checkedGeneratedItemIds: checkedGeneratedItemIds,
      removedGeneratedItemIds: removed.toList(),
      manualItems: manualItems,
    );
  }

  ShoppingState addManualItem(String name) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) return this;

    return ShoppingState(
      checkedGeneratedItemIds: checkedGeneratedItemIds,
      removedGeneratedItemIds: removedGeneratedItemIds,
      manualItems: <ShoppingManualItem>[
        ...manualItems,
        ShoppingManualItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          name: trimmed,
          checked: false,
        ),
      ],
    );
  }

  ShoppingState toggleManualItem(String id) {
    return ShoppingState(
      checkedGeneratedItemIds: checkedGeneratedItemIds,
      removedGeneratedItemIds: removedGeneratedItemIds,
      manualItems: manualItems.map((ShoppingManualItem item) {
        if (item.id != id) return item;
        return item.copyWith(checked: !item.checked);
      }).toList(),
    );
  }

  ShoppingState removeManualItem(String id) {
    return ShoppingState(
      checkedGeneratedItemIds: checkedGeneratedItemIds,
      removedGeneratedItemIds: removedGeneratedItemIds,
      manualItems:
          manualItems.where((ShoppingManualItem item) => item.id != id).toList(),
    );
  }
}

class KondateAppState {
  final List<Recipe> recipes;
  final MealPlanWeek mealPlan;
  final double targetServings;
  final List<String> trustedSites;
  final int topN;
  final ShoppingState shoppingState;

  const KondateAppState({
    required this.recipes,
    required this.mealPlan,
    required this.targetServings,
    required this.trustedSites,
    required this.topN,
    required this.shoppingState,
  });

  static const String _recipesKey = 'kondate_recipes_json';
  static const String _mealPlanKey = 'kondate_meal_plan_json';
  static const String _targetServingsKey = 'kondate_target_servings';
  static const String _trustedSitesKey = 'kondate_trusted_sites';
  static const String _topNKey = 'kondate_top_n';
  static const String _shoppingStateKey = 'kondate_shopping_state_json';

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
      shoppingState: ShoppingState.initial(),
    );
  }

  static Future<KondateAppState> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final String? recipesJson = prefs.getString(_recipesKey);
    final String? mealPlanJson = prefs.getString(_mealPlanKey);
    final String? shoppingStateJson = prefs.getString(_shoppingStateKey);

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

    ShoppingState shoppingState = const ShoppingState.initial();
    if (shoppingStateJson != null && shoppingStateJson.isNotEmpty) {
      final Map<String, dynamic> decoded =
          jsonDecode(shoppingStateJson) as Map<String, dynamic>;
      shoppingState = _shoppingStateFromMap(decoded);
    }

    return KondateAppState(
      recipes: recipes,
      mealPlan: mealPlan,
      targetServings: targetServings,
      trustedSites: trustedSites,
      topN: topN,
      shoppingState: shoppingState,
    );
  }

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'recipes': recipes.map((Recipe r) => _recipeToMap(r)).toList(),
      'mealPlan': _mealPlanToMap(mealPlan),
      'targetServings': targetServings,
      'trustedSites': trustedSites,
      'topN': topN,
      'shoppingState': _shoppingStateToMap(shoppingState),
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

    final Map<String, dynamic> rawShoppingState =
        (map['shoppingState'] as Map<String, dynamic>? ??
            <String, dynamic>{});

    return KondateAppState(
      recipes: recipes,
      mealPlan: _mealPlanFromMap(rawMealPlan),
      targetServings: (map['targetServings'] as num?)?.toDouble() ?? 2.5,
      trustedSites: (map['trustedSites'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(),
      topN: (map['topN'] as num?)?.toInt() ?? 3,
      shoppingState: _shoppingStateFromMap(rawShoppingState),
    );
  }

  Future<void> saveAll() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      _recipesKey,
      jsonEncode(recipes.map((Recipe r) => _recipeToMap(r)).toList()),
    );
    await prefs.setString(_mealPlanKey, jsonEncode(_mealPlanToMap(mealPlan)));
    await prefs.setString(
      _shoppingStateKey,
      jsonEncode(_shoppingStateToMap(shoppingState)),
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
      shoppingState: shoppingState,
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
      shoppingState: shoppingState,
    );
  }

  KondateAppState clearRecipes() {
    return KondateAppState(
      recipes: const <Recipe>[],
      mealPlan: mealPlan,
      targetServings: targetServings,
      trustedSites: trustedSites,
      topN: topN,
      shoppingState: shoppingState,
    );
  }

  KondateAppState incrementServings() {
    return KondateAppState(
      recipes: recipes,
      mealPlan: mealPlan,
      targetServings: targetServings + 0.5,
      trustedSites: trustedSites,
      topN: topN,
      shoppingState: shoppingState,
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
      shoppingState: shoppingState,
    );
  }

  KondateAppState incrementTopN() {
    return KondateAppState(
      recipes: recipes,
      mealPlan: mealPlan,
      targetServings: targetServings,
      trustedSites: trustedSites,
      topN: topN + 1,
      shoppingState: shoppingState,
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
      shoppingState: shoppingState,
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
      shoppingState: shoppingState,
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
      shoppingState: shoppingState,
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
      shoppingState: shoppingState,
    );
  }

  KondateAppState toggleGeneratedShoppingChecked(String itemId) {
    return KondateAppState(
      recipes: recipes,
      mealPlan: mealPlan,
      targetServings: targetServings,
      trustedSites: trustedSites,
      topN: topN,
      shoppingState: shoppingState.toggleGeneratedChecked(itemId),
    );
  }

  KondateAppState toggleGeneratedShoppingRemoved(String itemId) {
    return KondateAppState(
      recipes: recipes,
      mealPlan: mealPlan,
      targetServings: targetServings,
      trustedSites: trustedSites,
      topN: topN,
      shoppingState: shoppingState.toggleGeneratedRemoved(itemId),
    );
  }

  KondateAppState addManualShoppingItem(String name) {
    return KondateAppState(
      recipes: recipes,
      mealPlan: mealPlan,
      targetServings: targetServings,
      trustedSites: trustedSites,
      topN: topN,
      shoppingState: shoppingState.addManualItem(name),
    );
  }

  KondateAppState toggleManualShoppingItem(String id) {
    return KondateAppState(
      recipes: recipes,
      mealPlan: mealPlan,
      targetServings: targetServings,
      trustedSites: trustedSites,
      topN: topN,
      shoppingState: shoppingState.toggleManualItem(id),
    );
  }

  KondateAppState removeManualShoppingItem(String id) {
    return KondateAppState(
      recipes: recipes,
      mealPlan: mealPlan,
      targetServings: targetServings,
      trustedSites: trustedSites,
      topN: topN,
      shoppingState: shoppingState.removeManualItem(id),
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
    final Uri sourceUrl = Uri.parse(urlText);
    final HttpClient client = HttpClient();

    try {
      final HttpClientRequest request =
          await client.postUrl(Uri.parse('$backendBaseUrl/import'));
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(<String, dynamic>{
          'url': sourceUrl.toString(),
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
        sourceUrl: sourceUrl,
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

  static Map<String, dynamic> _shoppingStateToMap(ShoppingState state) {
    return <String, dynamic>{
      'checkedGeneratedItemIds': state.checkedGeneratedItemIds,
      'removedGeneratedItemIds': state.removedGeneratedItemIds,
      'manualItems': state.manualItems.map(_manualItemToMap).toList(),
    };
  }

  static ShoppingState _shoppingStateFromMap(Map<String, dynamic> map) {
    return ShoppingState(
      checkedGeneratedItemIds:
          (map['checkedGeneratedItemIds'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic e) => e.toString())
              .toList(),
      removedGeneratedItemIds:
          (map['removedGeneratedItemIds'] as List<dynamic>? ?? const <dynamic>[])
              .map((dynamic e) => e.toString())
              .toList(),
      manualItems: (map['manualItems'] as List<dynamic>? ?? const <dynamic>[])
          .map((dynamic e) => _manualItemFromMap(e as Map<String, dynamic>))
          .toList(),
    );
  }

  static Map<String, dynamic> _manualItemToMap(ShoppingManualItem item) {
    return <String, dynamic>{
      'id': item.id,
      'name': item.name,
      'checked': item.checked,
    };
  }

  static ShoppingManualItem _manualItemFromMap(Map<String, dynamic> map) {
    return ShoppingManualItem(
      id: map['id'] as String,
      name: map['name'] as String,
      checked: map['checked'] as bool? ?? false,
    );
  }
}

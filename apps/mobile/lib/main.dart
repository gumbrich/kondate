import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:recipe_parser/recipe_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'household_sync_provider.dart';
import 'recipe_search_provider.dart';
import 'sync_debug_screen.dart';

void main() {
  runApp(const KondateApp());
}

class KondateApp extends StatelessWidget {
  const KondateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: KondateHome());
  }
}

class KondateHome extends StatefulWidget {
  const KondateHome({super.key});

  @override
  State<KondateHome> createState() => _KondateHomeState();
}

class _KondateHomeState extends State<KondateHome> {
  static const String _recipesPrefsKey = 'saved_recipes_v1';
  static const String _servingsPrefsKey = 'target_servings_v1';
  static const String _mealPlanPrefsKey = 'meal_plan_v1';
  static const String _trustedSitesPrefsKey = 'trusted_sites_v1';
  static const String _topNPrefsKey = 'recipe_top_n_v1';

  static const List<String> _defaultTrustedSites = <String>[
    'chefkoch.de',
    'eatsmarter.de',
    'springlane.de',
  ];

  static const RecipeSearchProvider _recipeSearchProvider =
      MockRecipeSearchProvider();
  static const HouseholdSyncProvider _householdSyncProvider =
      MockHouseholdSyncProvider();

  final TextEditingController _urlController = TextEditingController();

  bool _loading = false;
  bool _dataLoaded = false;
  String? _error;

  final List<Recipe> _recipes = <Recipe>[];
  double _targetServings = 2.5;
  int _topN = 3;
  List<String> _trustedSites = List<String>.from(_defaultTrustedSites);

  MealPlanWeek _mealPlan = MealPlanWeek(
    entries: const <MealPlanEntry>[
      MealPlanEntry(weekday: WeekdayDe.montag),
      MealPlanEntry(weekday: WeekdayDe.dienstag),
      MealPlanEntry(weekday: WeekdayDe.mittwoch),
      MealPlanEntry(weekday: WeekdayDe.donnerstag),
      MealPlanEntry(weekday: WeekdayDe.freitag),
      MealPlanEntry(weekday: WeekdayDe.samstag),
      MealPlanEntry(weekday: WeekdayDe.sonntag),
    ],
  );

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final double? savedServings = prefs.getDouble(_servingsPrefsKey);
    if (savedServings != null && savedServings > 0) {
      _targetServings = savedServings;
    }

    final int? savedTopN = prefs.getInt(_topNPrefsKey);
    if (savedTopN != null && savedTopN > 0) {
      _topN = savedTopN;
    }

    final List<String>? savedSites = prefs.getStringList(_trustedSitesPrefsKey);
    if (savedSites != null && savedSites.isNotEmpty) {
      _trustedSites = savedSites;
    }

    final String? recipesRaw = prefs.getString(_recipesPrefsKey);
    if (recipesRaw != null && recipesRaw.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(recipesRaw) as List<dynamic>;
        final List<Recipe> loaded = decoded
            .whereType<Map<String, dynamic>>()
            .map(_recipeFromJson)
            .toList();

        _recipes
          ..clear()
          ..addAll(loaded);
      } catch (_) {
        _error = 'Could not restore saved recipes.';
      }
    }

    final String? mealPlanRaw = prefs.getString(_mealPlanPrefsKey);
    if (mealPlanRaw != null && mealPlanRaw.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(mealPlanRaw) as List<dynamic>;
        final List<MealPlanEntry> entries = decoded
            .whereType<Map<String, dynamic>>()
            .map(_mealPlanEntryFromJson)
            .toList();

        _mealPlan = MealPlanWeek(entries: entries);
      } catch (_) {
        _error = 'Could not restore meal plan.';
      }
    }

    if (!mounted) return;
    setState(() {
      _dataLoaded = true;
    });
  }

  Future<void> _saveRecipes() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_recipes.map(_recipeToJson).toList());
    await prefs.setString(_recipesPrefsKey, encoded);
  }

  Future<void> _saveServings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_servingsPrefsKey, _targetServings);
  }

  Future<void> _saveTopN() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_topNPrefsKey, _topN);
  }

  Future<void> _saveMealPlan() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String encoded =
        jsonEncode(_mealPlan.entries.map(_mealPlanEntryToJson).toList());
    await prefs.setString(_mealPlanPrefsKey, encoded);
  }

  Future<void> _saveTrustedSites() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_trustedSitesPrefsKey, _trustedSites);
  }

  Future<void> _incrementServings() async {
    setState(() {
      _targetServings += 0.5;
    });
    await _saveServings();
  }

  Future<void> _decrementServings() async {
    if (_targetServings <= 0.5) return;

    setState(() {
      _targetServings -= 0.5;
    });
    await _saveServings();
  }

  Future<void> _incrementTopN() async {
    setState(() {
      _topN += 1;
    });
    await _saveTopN();
  }

  Future<void> _decrementTopN() async {
    if (_topN <= 1) return;

    setState(() {
      _topN -= 1;
    });
    await _saveTopN();
  }

  Future<void> _importAndAdd() async {
    final String urlText = _urlController.text.trim();
    if (urlText.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final KondateRecipeImporter importer = KondateRecipeImporter();
      final Recipe recipe = await importer.importRecipe(
        url: Uri.parse(urlText),
        id: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      setState(() {
        _recipes.add(recipe);
        _urlController.clear();
      });

      await _saveRecipes();
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _openManualRecipeScreen() async {
    final Recipe? recipe = await Navigator.of(context).push<Recipe>(
      MaterialPageRoute(
        builder: (_) => const ManualRecipeScreen(),
      ),
    );

    if (recipe == null) return;

    setState(() {
      _recipes.add(recipe);
      _error = null;
    });

    await _saveRecipes();
  }

  Future<void> _openTrustedSitesScreen() async {
    final _TrustedSitesResult? result =
        await Navigator.of(context).push<_TrustedSitesResult>(
      MaterialPageRoute(
        builder: (_) => TrustedSitesScreen(
          initialSites: _trustedSites,
          initialTopN: _topN,
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      _trustedSites = result.sites;
      _topN = result.topN;
    });

    await _saveTrustedSites();
    await _saveTopN();
  }

  Future<void> _openSyncDebugScreen() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const SyncDebugScreen(
          syncProvider: _householdSyncProvider,
        ),
      ),
    );
  }

  Future<void> _removeRecipeAt(int index) async {
    setState(() {
      _recipes.removeAt(index);
    });
    await _saveRecipes();
  }

  Future<void> _clearRecipes() async {
    setState(() {
      _recipes.clear();
    });
    await _saveRecipes();
  }

  Future<void> _editWeekday(WeekdayDe weekday) async {
    final MealPlanEntry current =
        _mealPlan.entryFor(weekday) ?? MealPlanEntry(weekday: weekday);

    final _MealPlanEditResult? result =
        await Navigator.of(context).push<_MealPlanEditResult>(
      MaterialPageRoute(
        builder: (_) => MealPlanDayScreen(
          weekdayLabel: _weekdayLabel(weekday),
          currentDishIdea: current.dishIdea ?? '',
          currentRecipeId: current.recipeId,
          recipes: _recipes,
          trustedSites: _trustedSites,
          topN: _topN,
          recipeSearchProvider: _recipeSearchProvider,
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      if (result.importedRecipe != null) {
        final bool exists = _recipes.any(
          (Recipe r) => r.id == result.importedRecipe!.id,
        );
        if (!exists) {
          _recipes.add(result.importedRecipe!);
        }
      }

      _mealPlan = _mealPlan.upsert(
        current.copyWith(
          dishIdea: result.dishIdea,
          recipeId: result.recipeId,
        ),
      );
      _error = null;
    });

    await _saveRecipes();
    await _saveMealPlan();
  }

  Future<void> _clearWeekday(WeekdayDe weekday) async {
    final MealPlanEntry current =
        _mealPlan.entryFor(weekday) ?? MealPlanEntry(weekday: weekday);

    setState(() {
      _mealPlan = _mealPlan.upsert(
        current.copyWith(
          dishIdea: '',
          recipeId: null,
        ),
      );
    });

    await _saveMealPlan();
  }

  void _openShoppingList() {
    final List<Recipe> selectedRecipes = _selectedMealPlanRecipes();

    final ShoppingList list = IngredientAggregator.fromRecipes(
      selectedRecipes,
      targetServings: _targetServings,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShoppingListScreen(
          targetServings: _targetServings,
          list: list,
        ),
      ),
    );
  }

  List<Recipe> _selectedMealPlanRecipes() {
    final List<Recipe> result = <Recipe>[];

    for (final MealPlanEntry entry in _mealPlan.entries) {
      final String? recipeId = entry.recipeId;
      if (recipeId == null) continue;

      final Recipe? recipe = _findRecipeById(recipeId);
      if (recipe != null) {
        result.add(recipe);
      }
    }

    return result;
  }

  Recipe? _findRecipeById(String id) {
    for (final Recipe recipe in _recipes) {
      if (recipe.id == id) return recipe;
    }
    return null;
  }

  String _weekdayLabel(WeekdayDe weekday) {
    switch (weekday) {
      case WeekdayDe.montag:
        return 'Montag';
      case WeekdayDe.dienstag:
        return 'Dienstag';
      case WeekdayDe.mittwoch:
        return 'Mittwoch';
      case WeekdayDe.donnerstag:
        return 'Donnerstag';
      case WeekdayDe.freitag:
        return 'Freitag';
      case WeekdayDe.samstag:
        return 'Samstag';
      case WeekdayDe.sonntag:
        return 'Sonntag';
    }
  }

  String _mealPlanSubtitle(MealPlanEntry entry) {
    final Recipe? recipe =
        entry.recipeId == null ? null : _findRecipeById(entry.recipeId!);

    if (entry.dishIdea != null &&
        entry.dishIdea!.trim().isNotEmpty &&
        recipe != null) {
      return '${entry.dishIdea!.trim()} • ${recipe.title}';
    }

    if (entry.dishIdea != null && entry.dishIdea!.trim().isNotEmpty) {
      return entry.dishIdea!.trim();
    }

    if (recipe != null) {
      return recipe.title;
    }

    return 'No plan yet';
  }

  Map<String, dynamic> _recipeToJson(Recipe recipe) {
    return <String, dynamic>{
      'id': recipe.id,
      'title': recipe.title,
      'sourceUrl': recipe.sourceUrl.toString(),
      'defaultServings': recipe.defaultServings,
      'ingredients': recipe.ingredients.map(_ingredientLineToJson).toList(),
    };
  }

  Recipe _recipeFromJson(Map<String, dynamic> json) {
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

  Map<String, dynamic> _ingredientLineToJson(IngredientLine line) {
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

  IngredientLine _ingredientLineFromJson(Map<String, dynamic> json) {
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

  Map<String, dynamic> _mealPlanEntryToJson(MealPlanEntry entry) {
    return <String, dynamic>{
      'weekday': entry.weekday.name,
      'dishIdea': entry.dishIdea,
      'recipeId': entry.recipeId,
    };
  }

  MealPlanEntry _mealPlanEntryFromJson(Map<String, dynamic> json) {
    return MealPlanEntry(
      weekday: WeekdayDe.values.firstWhere(
        (WeekdayDe d) => d.name == json['weekday'],
        orElse: () => WeekdayDe.montag,
      ),
      dishIdea: json['dishIdea'] as String?,
      recipeId: json['recipeId'] as String?,
    );
  }

  Unit _unitFromName(String? name) {
    return Unit.values.firstWhere(
      (Unit u) => u.name == name,
      orElse: () => Unit.unknown,
    );
  }

  String _prettyNumber(double x) {
    final String s = x.toStringAsFixed(2);
    return s.replaceAll(RegExp(r'\.?0+$'), '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canGenerate =
        _selectedMealPlanRecipes().isNotEmpty && !_loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kondate – MVP'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Sync debug',
            icon: const Icon(Icons.cloud_sync),
            onPressed: _openSyncDebugScreen,
          ),
          IconButton(
            tooltip: 'Trusted sites',
            icon: const Icon(Icons.public),
            onPressed: _openTrustedSitesScreen,
          ),
          IconButton(
            tooltip: 'Clear imported recipes',
            icon: const Icon(Icons.delete_sweep),
            onPressed: _recipes.isEmpty ? null : _clearRecipes,
          ),
        ],
      ),
      body: !_dataLoaded
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Recipe URL (JSON-LD)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: <Widget>[
                      ElevatedButton(
                        onPressed: _loading ? null : _importAndAdd,
                        child: const Text('Import & add'),
                      ),
                      ElevatedButton(
                        onPressed: _loading ? null : _openManualRecipeScreen,
                        child: const Text('Manual recipe'),
                      ),
                      ElevatedButton(
                        onPressed: canGenerate ? _openShoppingList : null,
                        child: const Text('Shopping list'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      const Text(
                        'Household servings:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _decrementServings,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        _prettyNumber(_targetServings),
                        style: const TextStyle(fontSize: 18),
                      ),
                      IconButton(
                        onPressed: _incrementServings,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      const Text(
                        'Recipe suggestions:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _decrementTopN,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        'Top $_topN',
                        style: const TextStyle(fontSize: 18),
                      ),
                      IconButton(
                        onPressed: _incrementTopN,
                        icon: const Icon(Icons.add_circle_outline),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Weekly plan',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: WeekdayDe.values.map((WeekdayDe weekday) {
                        final MealPlanEntry entry =
                            _mealPlan.entryFor(weekday) ??
                                MealPlanEntry(weekday: weekday);

                        final bool hasAnything =
                            (entry.dishIdea?.trim().isNotEmpty ?? false) ||
                                entry.recipeId != null;

                        return Card(
                          child: ListTile(
                            title: Text(_weekdayLabel(weekday)),
                            subtitle: Text(_mealPlanSubtitle(entry)),
                            onTap: () => _editWeekday(weekday),
                            trailing: hasAnything
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => _clearWeekday(weekday),
                                  )
                                : const Icon(Icons.edit),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Saved recipes (${_recipes.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 180,
                    child: ListView.builder(
                      itemCount: _recipes.length,
                      itemBuilder: (_, int i) {
                        final Recipe r = _recipes[i];
                        return ListTile(
                          title: Text(r.title),
                          subtitle: Text(
                            r.sourceUrl.toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _removeRecipeAt(i),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _MealPlanEditResult {
  final String dishIdea;
  final String? recipeId;
  final Recipe? importedRecipe;

  const _MealPlanEditResult({
    required this.dishIdea,
    required this.recipeId,
    this.importedRecipe,
  });
}

class _TrustedSitesResult {
  final List<String> sites;
  final int topN;

  const _TrustedSitesResult({
    required this.sites,
    required this.topN,
  });
}

class MealPlanDayScreen extends StatefulWidget {
  final String weekdayLabel;
  final String currentDishIdea;
  final String? currentRecipeId;
  final List<Recipe> recipes;
  final List<String> trustedSites;
  final int topN;
  final RecipeSearchProvider recipeSearchProvider;

  const MealPlanDayScreen({
    super.key,
    required this.weekdayLabel,
    required this.currentDishIdea,
    required this.currentRecipeId,
    required this.recipes,
    required this.trustedSites,
    required this.topN,
    required this.recipeSearchProvider,
  });

  @override
  State<MealPlanDayScreen> createState() => _MealPlanDayScreenState();
}

class _MealPlanDayScreenState extends State<MealPlanDayScreen> {
  late final TextEditingController _dishIdeaController;
  late final List<Recipe> _recipes;
  String? _selectedRecipeId;
  String? _error;

  @override
  void initState() {
    super.initState();
    _dishIdeaController = TextEditingController(text: widget.currentDishIdea);
    _recipes = List<Recipe>.from(widget.recipes);
    _selectedRecipeId = widget.currentRecipeId;
  }

  Future<void> _openRecipeSuggestionScreen() async {
    final String dishIdea = _dishIdeaController.text.trim();
    if (dishIdea.isEmpty) {
      setState(() {
        _error = 'Please enter a dish idea first.';
      });
      return;
    }

    final Recipe? importedRecipe = await Navigator.of(context).push<Recipe>(
      MaterialPageRoute(
        builder: (_) => RecipeSuggestionScreen(
          dishIdea: dishIdea,
          trustedSites: widget.trustedSites,
          topN: widget.topN,
          recipeSearchProvider: widget.recipeSearchProvider,
        ),
      ),
    );

    if (importedRecipe == null) return;

    setState(() {
      _recipes.add(importedRecipe);
      _selectedRecipeId = importedRecipe.id;
      _error = null;
    });
  }

  void _save() {
    final Recipe? importedRecipe = _recipes.cast<Recipe?>().firstWhere(
          (Recipe? r) => r?.id == _selectedRecipeId,
          orElse: () => null,
        );

    Navigator.of(context).pop(
      _MealPlanEditResult(
        dishIdea: _dishIdeaController.text.trim(),
        recipeId: _selectedRecipeId,
        importedRecipe: importedRecipe,
      ),
    );
  }

  @override
  void dispose() {
    _dishIdeaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.weekdayLabel),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _dishIdeaController,
              decoration: const InputDecoration(
                labelText: 'Dish idea',
                hintText: 'e.g. Lasagne, Ramen, Curry',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _selectedRecipeId,
              decoration: const InputDecoration(
                labelText: 'Recipe',
              ),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('No recipe selected'),
                ),
                ..._recipes.map((Recipe recipe) {
                  return DropdownMenuItem<String?>(
                    value: recipe.id,
                    child: Text(recipe.title),
                  );
                }),
              ],
              onChanged: (String? value) {
                setState(() {
                  _selectedRecipeId = value;
                });
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: _openRecipeSuggestionScreen,
                child: Text('Find top ${widget.topN} suggestions'),
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const Spacer(),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class TrustedSitesScreen extends StatefulWidget {
  final List<String> initialSites;
  final int initialTopN;

  const TrustedSitesScreen({
    super.key,
    required this.initialSites,
    required this.initialTopN,
  });

  @override
  State<TrustedSitesScreen> createState() => _TrustedSitesScreenState();
}

class _TrustedSitesScreenState extends State<TrustedSitesScreen> {
  late final TextEditingController _newSiteController;
  late List<String> _sites;
  late int _topN;
  String? _error;

  @override
  void initState() {
    super.initState();
    _newSiteController = TextEditingController();
    _sites = List<String>.from(widget.initialSites);
    _topN = widget.initialTopN;
  }

  void _addSite() {
    final String raw = _newSiteController.text.trim().toLowerCase();
    if (raw.isEmpty) return;

    final String site = raw
        .replaceAll('https://', '')
        .replaceAll('http://', '')
        .replaceAll('/', '');

    if (site.isEmpty || !site.contains('.')) {
      setState(() {
        _error = 'Please enter a valid domain like chefkoch.de';
      });
      return;
    }

    if (_sites.contains(site)) {
      setState(() {
        _error = 'That site is already in the list.';
      });
      return;
    }

    setState(() {
      _sites.add(site);
      _sites.sort();
      _newSiteController.clear();
      _error = null;
    });
  }

  void _removeSite(String site) {
    setState(() {
      _sites.remove(site);
      if (_topN > _sites.length && _sites.isNotEmpty) {
        _topN = _sites.length;
      }
      if (_sites.isEmpty) {
        _topN = 1;
      }
    });
  }

  void _incrementTopN() {
    if (_topN >= _sites.length) return;
    setState(() {
      _topN += 1;
    });
  }

  void _decrementTopN() {
    if (_topN <= 1) return;
    setState(() {
      _topN -= 1;
    });
  }

  @override
  void dispose() {
    _newSiteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int maxUsableTopN = _sites.isEmpty ? 1 : _sites.length;
    if (_topN > maxUsableTopN) {
      _topN = maxUsableTopN;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trusted sites'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _newSiteController,
              decoration: const InputDecoration(
                labelText: 'Add website domain',
                hintText: 'e.g. chefkoch.de',
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: _addSite,
                child: const Text('Add site'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                const Text(
                  'Top suggestions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _decrementTopN,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_topN',
                  style: const TextStyle(fontSize: 18),
                ),
                IconButton(
                  onPressed: _incrementTopN,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _sites.length,
                itemBuilder: (_, int i) {
                  final String site = _sites[i];
                  return ListTile(
                    title: Text(site),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _removeSite(site),
                    ),
                  );
                },
              ),
            ),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(
                        _TrustedSitesResult(
                          sites: _sites,
                          topN: _topN,
                        ),
                      );
                    },
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class RecipeSuggestionScreen extends StatefulWidget {
  final String dishIdea;
  final List<String> trustedSites;
  final int topN;
  final RecipeSearchProvider recipeSearchProvider;

  const RecipeSuggestionScreen({
    super.key,
    required this.dishIdea,
    required this.trustedSites,
    required this.topN,
    required this.recipeSearchProvider,
  });

  @override
  State<RecipeSuggestionScreen> createState() => _RecipeSuggestionScreenState();
}

class _RecipeSuggestionScreenState extends State<RecipeSuggestionScreen> {
  final TextEditingController _chosenUrlController = TextEditingController();

  bool _importing = false;
  String? _error;

  Future<void> _openCandidate(RecipeSuggestionCandidate candidate) async {
    await launchUrl(
      candidate.openUri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _importChosenRecipe() async {
    final String urlText = _chosenUrlController.text.trim();
    if (urlText.isEmpty) {
      setState(() {
        _error = 'Please paste the chosen recipe URL.';
      });
      return;
    }

    setState(() {
      _importing = true;
      _error = null;
    });

    try {
      final KondateRecipeImporter importer = KondateRecipeImporter();
      final Recipe recipe = await importer.importRecipe(
        url: Uri.parse(urlText),
        id: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      if (!mounted) return;
      Navigator.of(context).pop(recipe);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _chosenUrlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RecipeSuggestionCandidate>>(
      future: widget.recipeSearchProvider.search(
        dishIdea: widget.dishIdea,
        trustedSites: widget.trustedSites,
        topN: widget.topN,
      ),
      builder: (BuildContext context,
          AsyncSnapshot<List<RecipeSuggestionCandidate>> snapshot) {
        final bool loading = snapshot.connectionState != ConnectionState.done;
        final List<RecipeSuggestionCandidate> candidates =
            snapshot.data ?? const <RecipeSuggestionCandidate>[];

        return Scaffold(
          appBar: AppBar(
            title: Text('Suggestions: ${widget.dishIdea}'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: <Widget>[
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Recipe candidates',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(height: 8),
                if (loading) const LinearProgressIndicator(),
                if (!loading && candidates.isEmpty)
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('No trusted sites configured yet.'),
                  ),
                ...candidates.map((RecipeSuggestionCandidate candidate) {
                  return Card(
                    child: ListTile(
                      title: Text(candidate.title),
                      subtitle: Text(candidate.subtitle),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => _openCandidate(candidate),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                TextField(
                  controller: _chosenUrlController,
                  decoration: const InputDecoration(
                    labelText: 'Chosen recipe URL',
                    hintText: 'Paste the final recipe URL here',
                  ),
                ),
                const SizedBox(height: 12),
                if (_importing) const LinearProgressIndicator(),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ElevatedButton(
                    onPressed: _importing ? null : _importChosenRecipe,
                    child: const Text('Import selected recipe'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class ManualRecipeScreen extends StatefulWidget {
  const ManualRecipeScreen({super.key});

  @override
  State<ManualRecipeScreen> createState() => _ManualRecipeScreenState();
}

class _ManualRecipeScreenState extends State<ManualRecipeScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _servingsController =
      TextEditingController(text: '2.5');
  final TextEditingController _ingredientsController = TextEditingController();

  String? _error;

  Recipe _buildRecipe() {
    final String title = _titleController.text.trim();
    final String ingredientsText = _ingredientsController.text.trim();
    final double? servings =
        double.tryParse(_servingsController.text.trim().replaceAll(',', '.'));

    if (title.isEmpty) {
      throw Exception('Please enter a recipe title.');
    }
    if (ingredientsText.isEmpty) {
      throw Exception('Please enter at least one ingredient line.');
    }

    final List<String> lines = ingredientsText
        .split('\n')
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();

    final List<IngredientLine> ingredients = lines.map((String raw) {
      final Quantity? q = QuantityParserDe.parseLeadingQuantity(raw);
      return IngredientLine(
        raw: raw,
        quantity: q,
        normalizedName: null,
      );
    }).toList();

    return Recipe(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      sourceUrl: Uri.parse('manual://recipe/$title'),
      defaultServings: servings,
      ingredients: ingredients,
    );
  }

  void _save() {
    try {
      final Recipe recipe = _buildRecipe();
      Navigator.of(context).pop(recipe);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _servingsController.dispose();
    _ingredientsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual recipe'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Recipe title',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _servingsController,
              decoration: const InputDecoration(
                labelText: 'Recipe servings',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _ingredientsController,
                decoration: const InputDecoration(
                  labelText: 'Ingredients (one per line)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
                expands: true,
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class ShoppingListScreen extends StatefulWidget {
  final double targetServings;
  final ShoppingList list;

  const ShoppingListScreen({
    super.key,
    required this.targetServings,
    required this.list,
  });

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  static const List<CategoryDe> _categoryOrder = <CategoryDe>[
    CategoryDe.gemuese,
    CategoryDe.obst,
    CategoryDe.milchprodukte,
    CategoryDe.fleischFisch,
    CategoryDe.tiefkuehl,
    CategoryDe.konserven,
    CategoryDe.trockenwaren,
    CategoryDe.backen,
    CategoryDe.oeleSaucen,
    CategoryDe.gewuerze,
    CategoryDe.getraenke,
    CategoryDe.sonstiges,
  ];

  static const String _prefsKey = 'shopping_checked_keys';

  final Set<String> _checked = <String>{};
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadChecked();
  }

  Future<void> _loadChecked() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList(_prefsKey) ?? <String>[];

    if (!mounted) return;

    setState(() {
      _checked
        ..clear()
        ..addAll(saved);
      _prefsLoaded = true;
    });
  }

  Future<void> _saveChecked() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _checked.toList());
  }

  Future<void> _clearChecked() async {
    setState(() {
      _checked.clear();
    });
    await _saveChecked();
  }

  String _itemKey(ShoppingListItem item) {
    final Quantity? q = item.quantity;
    if (q == null) return '${item.category.name}__${item.name}';
    return '${item.category.name}__${item.name}__${q.value}__${q.unit.name}';
  }

  String _categoryLabel(CategoryDe c) {
    switch (c) {
      case CategoryDe.gemuese:
        return 'Gemüse';
      case CategoryDe.obst:
        return 'Obst';
      case CategoryDe.milchprodukte:
        return 'Milchprodukte';
      case CategoryDe.fleischFisch:
        return 'Fleisch / Fisch';
      case CategoryDe.trockenwaren:
        return 'Trockenwaren';
      case CategoryDe.backen:
        return 'Backen';
      case CategoryDe.gewuerze:
        return 'Gewürze';
      case CategoryDe.oeleSaucen:
        return 'Öle & Saucen';
      case CategoryDe.konserven:
        return 'Konserven';
      case CategoryDe.tiefkuehl:
        return 'Tiefkühl';
      case CategoryDe.getraenke:
        return 'Getränke';
      case CategoryDe.sonstiges:
        return 'Sonstiges';
    }
  }

  String _prettyNumber(double x) {
    final String s = x.toStringAsFixed(2);
    return s.replaceAll(RegExp(r'\.?0+$'), '');
  }

  String _formatItem(ShoppingListItem item) {
    final Quantity? q = item.quantity;
    final String displayName = item.displayName;

    if (q == null) {
      return displayName;
    }

    final String unit = UnitFormatDe.short(q.unit);
    final String value = _prettyNumber(q.value);

    if (unit.isEmpty) {
      return '$value $displayName';
    }

    return '$value $unit $displayName';
  }

  @override
  Widget build(BuildContext context) {
    final Map<CategoryDe, List<ShoppingListItem>> byCat =
        <CategoryDe, List<ShoppingListItem>>{};
    for (final ShoppingListItem it in widget.list.items) {
      (byCat[it.category] ??= <ShoppingListItem>[]).add(it);
    }

    final List<_Row> rows = <_Row>[];
    for (final CategoryDe cat in _categoryOrder) {
      final List<ShoppingListItem>? items = byCat[cat];
      if (items == null || items.isEmpty) continue;

      items.sort((ShoppingListItem a, ShoppingListItem b) {
        return a.displayName.compareTo(b.displayName);
      });

      rows.add(_Row.header(_categoryLabel(cat)));
      for (final ShoppingListItem it in items) {
        rows.add(_Row.item(it));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Shopping list (${_prettyNumber(widget.targetServings)})'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Clear checked',
            icon: const Icon(Icons.refresh),
            onPressed: _clearChecked,
          ),
        ],
      ),
      body: !_prefsLoaded
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: rows.length,
              itemBuilder: (_, int i) {
                final _Row row = rows[i];

                if (row.isHeader) {
                  return Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      row.headerText!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }

                final ShoppingListItem item = row.item!;
                final String key = _itemKey(item);
                final bool checked = _checked.contains(key);

                return CheckboxListTile(
                  value: checked,
                  title: Text(
                    _formatItem(item),
                    style: TextStyle(
                      decoration:
                          checked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  onChanged: (bool? v) async {
                    setState(() {
                      if (v == true) {
                        _checked.add(key);
                      } else {
                        _checked.remove(key);
                      }
                    });
                    await _saveChecked();
                  },
                );
              },
            ),
    );
  }
}

class _Row {
  final bool isHeader;
  final String? headerText;
  final ShoppingListItem? item;

  const _Row._({
    required this.isHeader,
    this.headerText,
    this.item,
  });

  factory _Row.header(String text) {
    return _Row._(
      isHeader: true,
      headerText: text,
    );
  }

  factory _Row.item(ShoppingListItem item) {
    return _Row._(
      isHeader: false,
      item: item,
    );
  }
}

import 'package:core/core.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'household_sync_provider.dart';
import 'manual_recipe_screen.dart';
import 'meal_plan_day_screen.dart';
import 'recipe_list_section.dart';
import 'recipe_search_provider.dart';
import 'shopping_list_screen.dart';
import 'sync_debug_screen.dart';
import 'trusted_sites_screen.dart';
import 'weekly_plan_section.dart';
import 'weekly_suggestion_service.dart';
import 'weekly_suggestions_screen.dart';

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
  static const RecipeSearchProvider _recipeSearchProvider =
      MockRecipeSearchProvider();
  static const HouseholdSyncProvider _householdSyncProvider =
      MockHouseholdSyncProvider();

  final WeeklySuggestionService _weeklySuggestionService =
      const WeeklySuggestionService(
    recipeSearchProvider: _recipeSearchProvider,
  );

  final TextEditingController _urlController = TextEditingController();

  bool _loading = false;
  bool _dataLoaded = false;
  String? _error;
  KondateAppState _appState = KondateAppState.initial();

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final KondateAppState state = await KondateAppState.load();
      if (!mounted) return;
      setState(() {
        _appState = state;
        _dataLoaded = true;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dataLoaded = true;
        _error = 'Could not restore app state: $e';
      });
    }
  }

  Future<void> _persistState() async {
    await _appState.saveAll();
  }

  Future<void> _incrementServings() async {
    setState(() {
      _appState = _appState.incrementServings();
    });
    await _persistState();
  }

  Future<void> _decrementServings() async {
    setState(() {
      _appState = _appState.decrementServings();
    });
    await _persistState();
  }

  Future<void> _incrementTopN() async {
    setState(() {
      _appState = _appState.incrementTopN();
    });
    await _persistState();
  }

  Future<void> _decrementTopN() async {
    setState(() {
      _appState = _appState.decrementTopN();
    });
    await _persistState();
  }

  Future<void> _importAndAdd() async {
    final String urlText = _urlController.text.trim();
    if (urlText.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final Recipe recipe = await KondateAppState.importRecipeFromUrl(urlText);

      setState(() {
        _appState = _appState.addRecipe(recipe);
        _urlController.clear();
      });

      await _persistState();
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
      _appState = _appState.addRecipe(recipe);
      _error = null;
    });

    await _persistState();
  }

  Future<void> _openTrustedSitesScreen() async {
    final TrustedSitesResult? result =
        await Navigator.of(context).push<TrustedSitesResult>(
      MaterialPageRoute(
        builder: (_) => TrustedSitesScreen(
          initialSites: _appState.trustedSites,
          initialTopN: _appState.topN,
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      _appState = _appState.updateTrustedSites(
        sites: result.sites,
        topN: result.topN,
      );
    });

    await _persistState();
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

  Future<void> _openWeeklySuggestions() async {
    final Map<WeekdayDe, RecipeSuggestionCandidate>? result =
        await Navigator.of(context).push<
            Map<WeekdayDe, RecipeSuggestionCandidate>>(
      MaterialPageRoute(
        builder: (_) => WeeklySuggestionsScreen(
          suggestionService: _weeklySuggestionService,
          mealPlan: _appState.mealPlan,
          trustedSites: _appState.trustedSites,
          topN: _appState.topN,
        ),
      ),
    );

    if (result == null) return;

    for (final MapEntry<WeekdayDe, RecipeSuggestionCandidate> entry
        in result.entries) {
      final WeekdayDe weekday = entry.key;
      final RecipeSuggestionCandidate candidate = entry.value;
      final String currentDishIdea =
          _appState.mealPlan.entryFor(weekday)?.dishIdea ?? '';

      setState(() {
        _appState = _appState.updateMealPlanEntry(
          weekday: weekday,
          dishIdea: currentDishIdea,
          recipeId: candidate.openUri.toString(),
        );
      });
    }

    await _persistState();
  }

  Future<void> _removeRecipeAt(int index) async {
    setState(() {
      _appState = _appState.removeRecipeAt(index);
    });
    await _persistState();
  }

  Future<void> _clearRecipes() async {
    setState(() {
      _appState = _appState.clearRecipes();
    });
    await _persistState();
  }

  Future<void> _editWeekday(WeekdayDe weekday) async {
    final MealPlanEntry current =
        _appState.mealPlan.entryFor(weekday) ?? MealPlanEntry(weekday: weekday);

    final MealPlanEditResult? result =
        await Navigator.of(context).push<MealPlanEditResult>(
      MaterialPageRoute(
        builder: (_) => MealPlanDayScreen(
          weekdayLabel: _weekdayLabel(weekday),
          currentDishIdea: current.dishIdea ?? '',
          currentRecipeId: current.recipeId,
          recipes: _appState.recipes,
          trustedSites: _appState.trustedSites,
          topN: _appState.topN,
          recipeSearchProvider: _recipeSearchProvider,
        ),
      ),
    );

    if (result == null) return;

    setState(() {
      if (result.importedRecipe != null &&
          !_appState.recipes.any(
            (Recipe r) => r.id == result.importedRecipe!.id,
          )) {
        _appState = _appState.addRecipe(result.importedRecipe!);
      }

      _appState = _appState.updateMealPlanEntry(
        weekday: weekday,
        dishIdea: result.dishIdea,
        recipeId: result.recipeId,
      );
      _error = null;
    });

    await _persistState();
  }

  Future<void> _clearWeekday(WeekdayDe weekday) async {
    setState(() {
      _appState = _appState.clearWeekday(weekday);
    });
    await _persistState();
  }

  void _openShoppingList() {
    final ShoppingList list = IngredientAggregator.fromRecipes(
      _appState.selectedMealPlanRecipes(),
      targetServings: _appState.targetServings,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShoppingListScreen(
          targetServings: _appState.targetServings,
          list: list,
        ),
      ),
    );
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

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canGenerate =
        _appState.selectedMealPlanRecipes().isNotEmpty && !_loading;

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
            onPressed: _appState.recipes.isEmpty ? null : _clearRecipes,
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
                        onPressed: _openWeeklySuggestions,
                        child: const Text('Suggest recipes'),
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
                        _appState.targetServings.toString(),
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
                        'Top ${_appState.topN}',
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
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: <Widget>[
                          WeeklyPlanSection(
                            mealPlan: _appState.mealPlan,
                            recipes: _appState.recipes,
                            onEdit: _editWeekday,
                            onClear: _clearWeekday,
                          ),
                          const SizedBox(height: 12),
                          RecipeListSection(
                            recipes: _appState.recipes,
                            onDelete: _removeRecipeAt,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

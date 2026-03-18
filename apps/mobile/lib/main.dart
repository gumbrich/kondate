import 'package:core/core.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'household_api.dart';
import 'household_local_store.dart';
import 'household_screen.dart';
import 'household_sync_provider.dart';
import 'manual_recipe_screen.dart';
import 'meal_plan_day_screen.dart';
import 'recipe_list_section.dart';
import 'recipe_search_provider.dart';
import 'shopping_list_screen.dart';
import 'sync_debug_screen.dart';
import 'sync_status.dart';
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
      BackendRecipeSearchProvider();
  static const HouseholdSyncProvider _householdSyncProvider =
      MockHouseholdSyncProvider();

  final WeeklySuggestionService _weeklySuggestionService =
      const WeeklySuggestionService(
    recipeSearchProvider: _recipeSearchProvider,
  );

  final HouseholdApi _householdApi = HouseholdApi();
  final HouseholdLocalStore _householdLocalStore = HouseholdLocalStore();
  final TextEditingController _urlController = TextEditingController();

  bool _loading = false;
  bool _dataLoaded = false;
  bool _syncingHousehold = false;

  String? _error;
  String? _householdId;
  String? _joinCode;
  SyncStatus _syncStatus = const SyncStatus.initial();

  KondateAppState _appState = KondateAppState.initial();

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    try {
      final KondateAppState state = await KondateAppState.load();
      final StoredHouseholdInfo? household = await _householdLocalStore.load();

      if (!mounted) return;

      setState(() {
        _appState = state;
        _householdId = household?.householdId;
        _joinCode = household?.joinCode;
        _dataLoaded = true;
        _error = null;
      });

      if (_householdId != null) {
        await _loadFromHousehold(showLoader: false);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _dataLoaded = true;
        _error = 'App-Zustand konnte nicht geladen werden: $e';
      });
    }
  }

  Future<void> _persistState() async {
    await _appState.saveAll();
    await _autoSyncToHousehold();
  }

  Future<void> _autoSyncToHousehold() async {
    if (_householdId == null) return;

    try {
      if (mounted) {
        setState(() {
          _syncingHousehold = true;
        });
      }

      final String? updatedAt = await _householdApi.saveState(
        _householdId!,
        _appState.toMap(),
        lastSeenUpdatedAt: _syncStatus.lastRemoteUpdatedAt,
      );

      if (mounted) {
        setState(() {
          _syncStatus = _syncStatus.pushedNow(remoteUpdatedAt: updatedAt);
        });
      }
    } on HouseholdConflictException catch (e) {
      if (mounted) {
        setState(() {
          _error =
              'Der Haushalt wurde auf einem anderen Gerät geändert. Bitte zuerst aktualisieren.';
          _syncStatus = _syncStatus.withError(e.toString());
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Automatische Haushalt-Synchronisierung fehlgeschlagen: $e';
          _syncStatus = _syncStatus.withError(e.toString());
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _syncingHousehold = false;
        });
      }
    }
  }

  Future<void> _openHouseholdScreen() async {
    final HouseholdInfo? info = await Navigator.of(context).push<HouseholdInfo>(
      MaterialPageRoute(
        builder: (_) => const HouseholdScreen(),
      ),
    );

    if (info == null) return;

    await _householdLocalStore.save(
      householdId: info.householdId,
      joinCode: info.joinCode,
    );

    if (!mounted) return;
    setState(() {
      _householdId = info.householdId;
      _joinCode = info.joinCode;
      _error = null;
    });

    await _loadFromHousehold(showLoader: true);
  }

  Future<void> _disconnectHousehold() async {
    await _householdLocalStore.clear();

    setState(() {
      _householdId = null;
      _joinCode = null;
      _error = null;
      _syncStatus = const SyncStatus.initial();
    });
  }

  Future<void> _loadFromHousehold({bool showLoader = true}) async {
    if (_householdId == null) {
      setState(() {
        _error = 'Noch kein Haushalt verbunden.';
      });
      return;
    }

    if (showLoader) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else {
      setState(() {
        _error = null;
      });
    }

    try {
      final HouseholdStatePayload payload =
          await _householdApi.loadState(_householdId!);

      if (!mounted) return;

      setState(() {
        _appState = KondateAppState.fromMap(payload.state);
        _syncStatus = _syncStatus.pulledNow(
          remoteUpdatedAt: payload.updatedAt,
        );
      });

      await _appState.saveAll();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Haushaltszustand konnte nicht geladen werden: $e';
        _syncStatus = _syncStatus.withError(e.toString());
      });
    } finally {
      if (showLoader && mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  Future<void> _refreshHousehold() async {
    await _loadFromHousehold(showLoader: true);
  }

  Future<void> _saveToHousehold() async {
    if (_householdId == null) {
      setState(() {
        _error = 'Noch kein Haushalt verbunden.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final String? updatedAt = await _householdApi.saveState(
        _householdId!,
        _appState.toMap(),
        lastSeenUpdatedAt: _syncStatus.lastRemoteUpdatedAt,
      );
      setState(() {
        _syncStatus = _syncStatus.pushedNow(remoteUpdatedAt: updatedAt);
      });
    } on HouseholdConflictException {
      setState(() {
        _error =
            'Der entfernte Haushaltszustand wurde geändert. Bitte zuerst aktualisieren.';
      });
    } catch (e) {
      setState(() {
        _error = 'Haushaltszustand konnte nicht gespeichert werden: $e';
        _syncStatus = _syncStatus.withError(e.toString());
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
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
    final Map<WeekdayDe, Recipe>? result =
        await Navigator.of(context).push<Map<WeekdayDe, Recipe>>(
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

    for (final MapEntry<WeekdayDe, Recipe> entry in result.entries) {
      final WeekdayDe weekday = entry.key;
      final Recipe recipe = entry.value;
      final String currentDishIdea =
          _appState.mealPlan.entryFor(weekday)?.dishIdea ?? '';

      setState(() {
        if (!_appState.recipes.any((Recipe r) => r.id == recipe.id)) {
          _appState = _appState.addRecipe(recipe);
        }

        _appState = _appState.updateMealPlanEntry(
          weekday: weekday,
          dishIdea: currentDishIdea,
          recipeId: recipe.id,
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

  Future<void> _openShoppingList() async {
    final KondateAppState? updatedState =
        await Navigator.of(context).push<KondateAppState>(
      MaterialPageRoute(
        builder: (_) => ShoppingListScreen(
          appState: _appState,
        ),
      ),
    );

    if (updatedState == null) return;

    setState(() {
      _appState = updatedState;
    });

    await _persistState();
  }

  int _daysNeedingSuggestions() {
    int count = 0;

    for (final WeekdayDe weekday in WeekdayDe.values) {
      final MealPlanEntry? entry = _appState.mealPlan.entryFor(weekday);

      if (entry == null) continue;

      final bool hasDishIdea =
          entry.dishIdea != null && entry.dishIdea!.trim().isNotEmpty;
      final bool hasRecipe = entry.recipeId != null;

      if (hasDishIdea && !hasRecipe) {
        count++;
      }
    }

    return count;
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

  String _formatSyncStatus() {
    final List<String> parts = <String>[];

    if (_syncStatus.lastPulledAt != null) {
      parts.add(
        'Geladen ${_syncStatus.lastPulledAt!.hour.toString().padLeft(2, '0')}:${_syncStatus.lastPulledAt!.minute.toString().padLeft(2, '0')}',
      );
    }
    if (_syncStatus.lastPushedAt != null) {
      parts.add(
        'Gespeichert ${_syncStatus.lastPushedAt!.hour.toString().padLeft(2, '0')}:${_syncStatus.lastPushedAt!.minute.toString().padLeft(2, '0')}',
      );
    }
    if (_syncStatus.lastRemoteUpdatedAt != null) {
      parts.add('Remote gesehen');
    }
    if (_syncStatus.lastError != null) {
      parts.add('Letzter Sync-Fehler');
    }

    if (parts.isEmpty) {
      return 'Noch keine Synchronisierung';
    }

    return parts.join(' • ');
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
    final int suggestionCount = _daysNeedingSuggestions();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kondate'),
        actions: <Widget>[
          if (_householdId != null)
            IconButton(
              tooltip: 'Haushalt aktualisieren',
              icon: const Icon(Icons.refresh),
              onPressed: _loading ? null : _refreshHousehold,
            ),
          IconButton(
            tooltip: 'Haushalt',
            icon: const Icon(Icons.group),
            onPressed: _openHouseholdScreen,
          ),
          IconButton(
            tooltip: 'Sync-Debug',
            icon: const Icon(Icons.cloud_sync),
            onPressed: _openSyncDebugScreen,
          ),
          IconButton(
            tooltip: 'Vertrauenswürdige Seiten',
            icon: const Icon(Icons.public),
            onPressed: _openTrustedSitesScreen,
          ),
          IconButton(
            tooltip: 'Importierte Rezepte löschen',
            icon: const Icon(Icons.delete_sweep),
            onPressed: _appState.recipes.isEmpty ? null : _clearRecipes,
          ),
        ],
      ),
      body: !_dataLoaded
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  if (_householdId != null)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text('Haushalt: $_householdId'),
                          if (_joinCode != null) Text('Beitrittscode: $_joinCode'),
                          const SizedBox(height: 4),
                          Text(
                            _formatSyncStatus(),
                            style: const TextStyle(fontSize: 12),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            children: <Widget>[
                              ElevatedButton(
                                onPressed: _loading ? null : _loadFromHousehold,
                                child: const Text('Haushalt laden'),
                              ),
                              ElevatedButton(
                                onPressed: _loading ? null : _saveToHousehold,
                                child: const Text('Haushalt speichern'),
                              ),
                              OutlinedButton(
                                onPressed:
                                    _loading ? null : _disconnectHousehold,
                                child: const Text('Trennen'),
                              ),
                            ],
                          ),
                          if (_syncingHousehold) ...<Widget>[
                            const SizedBox(height: 8),
                            const Row(
                              children: <Widget>[
                                SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 8),
                                Text('Haushalt wird synchronisiert...'),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Rezept-URL hier einfügen',
                      hintText: 'https://www.chefkoch.de/rezepte/...',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: <Widget>[
                          const Text(
                            'Aktionen',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.auto_awesome),
                            label: Text('Rezepte vorschlagen ($suggestionCount)'),
                            onPressed:
                                suggestionCount > 0 ? _openWeeklySuggestions : null,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.shopping_cart),
                            label: const Text('Einkaufsliste öffnen'),
                            onPressed: canGenerate ? _openShoppingList : null,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            icon: const Icon(Icons.link),
                            label: const Text('Eingefügte URL importieren'),
                            onPressed: _loading ? null : _importAndAdd,
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.edit),
                            label: const Text('Rezept manuell erstellen'),
                            onPressed: _loading ? null : _openManualRecipeScreen,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        children: <Widget>[
                          Row(
                            children: <Widget>[
                              const Expanded(
                                child: Text(
                                  'Portionen im Haushalt',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
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
                          const Divider(),
                          Row(
                            children: <Widget>[
                              const Expanded(
                                child: Text(
                                  'Anzahl Rezeptvorschläge',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
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
                        ],
                      ),
                    ),
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
    );
  }
}

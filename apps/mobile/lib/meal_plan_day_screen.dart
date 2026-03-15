import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'recipe_search_provider.dart';

class MealPlanEditResult {
  final String dishIdea;
  final String? recipeId;
  final Recipe? importedRecipe;

  const MealPlanEditResult({
    required this.dishIdea,
    required this.recipeId,
    this.importedRecipe,
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
      final bool alreadyExists =
          _recipes.any((Recipe r) => r.id == importedRecipe.id);
      if (!alreadyExists) {
        _recipes.add(importedRecipe);
      }
      _selectedRecipeId = importedRecipe.id;
      _error = null;
    });
  }

  void _save() {
    Recipe? importedRecipe;
    if (_selectedRecipeId != null) {
      for (final Recipe recipe in _recipes) {
        if (recipe.id == _selectedRecipeId) {
          importedRecipe = recipe;
          break;
        }
      }
    }

    Navigator.of(context).pop(
      MealPlanEditResult(
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
    final bool selectedRecipeStillExists = _selectedRecipeId != null &&
        _recipes.any((Recipe recipe) => recipe.id == _selectedRecipeId);

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
              initialValue:
                  selectedRecipeStillExists ? _selectedRecipeId : null,
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
  bool _importing = false;
  String? _error;
  String? _importingKey;
  Recipe? _selectedRecipe;

  Future<void> _openCandidateInBrowser(
    RecipeSuggestionCandidate candidate,
  ) async {
    await launchUrl(
      candidate.openUri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _importCandidate(
    RecipeSuggestionCandidate candidate,
  ) async {
    final String key = candidate.openUri.toString();

    setState(() {
      _importing = true;
      _importingKey = key;
      _error = null;
    });

    try {
      final Recipe recipe = await KondateAppState.importRecipeFromUrl(
        candidate.openUri.toString(),
      );

      if (!mounted) return;
      setState(() {
        _selectedRecipe = recipe;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Import failed for ${candidate.openUri}: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _importing = false;
          _importingKey = null;
        });
      }
    }
  }

  void _confirmImportedRecipe() {
    if (_selectedRecipe == null) return;
    Navigator.of(context).pop(_selectedRecipe);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RecipeSearchDebugResult>(
      future: widget.recipeSearchProvider.searchDebug(
        dishIdea: widget.dishIdea,
        trustedSites: widget.trustedSites,
        topN: widget.topN,
      ),
      builder: (
        BuildContext context,
        AsyncSnapshot<RecipeSearchDebugResult> snapshot,
      ) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Suggestions: ${widget.dishIdea}'),
            ),
            body: const Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          return Scaffold(
            appBar: AppBar(
              title: Text('Suggestions: ${widget.dishIdea}'),
            ),
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Could not load suggestions: ${snapshot.error}',
                style: const TextStyle(color: Colors.red),
              ),
            ),
          );
        }

        final RecipeSearchDebugResult debug =
            snapshot.data ??
                const RecipeSearchDebugResult(
                  candidates: <RecipeSuggestionCandidate>[],
                  debugLines: <String>[],
                );

        final List<RecipeSuggestionCandidate> candidates = debug.candidates;
        final bool canConfirm = _selectedRecipe != null;

        return Scaffold(
          appBar: AppBar(
            title: Text('Suggestions: ${widget.dishIdea}'),
            actions: <Widget>[
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: canConfirm ? _confirmImportedRecipe : null,
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: <Widget>[
                Text(
                  'Trusted sites: ${widget.trustedSites.join(', ')}',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Tap a suggestion to import it directly. Use the external-link button only if you want to inspect the page first.',
                ),
                const SizedBox(height: 12),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (candidates.isEmpty)
                  Text(
                    'No recipe results found for "${widget.dishIdea}" on the configured trusted sites.',
                  ),
                ...candidates.map((RecipeSuggestionCandidate candidate) {
                  final String key = candidate.openUri.toString();
                  final bool importing = _importing && _importingKey == key;
                  final bool selected = _selectedRecipe != null &&
                      _selectedRecipe!.sourceUrl.toString() ==
                          candidate.openUri.toString();

                  return Card(
                    child: ListTile(
                      title: Text(candidate.title),
                      subtitle: Text(
                        selected
                            ? '${candidate.subtitle}\nImported: ${_selectedRecipe!.title}'
                            : candidate.subtitle,
                      ),
                      isThreeLine: selected,
                      leading: importing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              selected
                                  ? Icons.check_circle
                                  : Icons.download,
                              color: selected ? Colors.green : null,
                            ),
                      trailing: IconButton(
                        icon: const Icon(Icons.open_in_new),
                        tooltip: 'Open in browser',
                        onPressed: () => _openCandidateInBrowser(candidate),
                      ),
                      onTap:
                          importing ? null : () => _importCandidate(candidate),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                const Text(
                  'Search debug',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ...debug.debugLines.map((String line) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• $line',
                      style: const TextStyle(fontSize: 12),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }
}

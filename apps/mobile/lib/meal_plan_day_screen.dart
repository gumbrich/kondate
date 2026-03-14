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
      final Recipe recipe = await KondateAppState.importRecipeFromUrl(urlText);

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
      builder: (
        BuildContext context,
        AsyncSnapshot<List<RecipeSuggestionCandidate>> snapshot,
      ) {
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

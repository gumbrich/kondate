import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'meal_plan_suggestion_models.dart';
import 'recipe_search_provider.dart';
import 'weekly_suggestion_service.dart';

class WeeklySuggestionsScreen extends StatefulWidget {
  final WeeklySuggestionService suggestionService;
  final MealPlanWeek mealPlan;
  final List<String> trustedSites;
  final int topN;

  const WeeklySuggestionsScreen({
    super.key,
    required this.suggestionService,
    required this.mealPlan,
    required this.trustedSites,
    required this.topN,
  });

  @override
  State<WeeklySuggestionsScreen> createState() =>
      _WeeklySuggestionsScreenState();
}

class _WeeklySuggestionsScreenState extends State<WeeklySuggestionsScreen> {
  late Future<List<DayRecipeSuggestions>> _future;

  final Map<WeekdayDe, Recipe> _selected = <WeekdayDe, Recipe>{};
  final Set<String> _importingKeys = <String>{};

  String? _error;

  @override
  void initState() {
    super.initState();

    _future = widget.suggestionService.suggestForMealPlan(
      mealPlan: widget.mealPlan,
      trustedSites: widget.trustedSites,
      topN: widget.topN,
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

  String _candidateKey(
    WeekdayDe weekday,
    RecipeSuggestionCandidate candidate,
  ) {
    return '${weekday.name}_${candidate.openUri}';
  }

  Future<void> _openRecipeInBrowser(RecipeSuggestionCandidate candidate) async {
    await launchUrl(
      candidate.openUri,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _importCandidate(
    WeekdayDe weekday,
    RecipeSuggestionCandidate candidate,
  ) async {
    final String key = _candidateKey(weekday, candidate);

    setState(() {
      _importingKeys.add(key);
      _error = null;
    });

    try {
      final Recipe recipe = await KondateAppState.importRecipeFromUrl(
        candidate.openUri.toString(),
      );

      if (!mounted) return;

      setState(() {
        _selected[weekday] = recipe;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Import failed for ${candidate.openUri}: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _importingKeys.remove(key);
        });
      }
    }
  }

  void _confirm() {
    if (_selected.isEmpty) return;
    Navigator.of(context).pop(_selected);
  }

  @override
  Widget build(BuildContext context) {
    final bool canConfirm = _selected.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe suggestions'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: canConfirm ? _confirm : null,
          ),
        ],
      ),
      body: FutureBuilder<List<DayRecipeSuggestions>>(
        future: _future,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<DayRecipeSuggestions>> snapshot,
        ) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'Could not load suggestions: ${snapshot.error}',
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            );
          }

          final List<DayRecipeSuggestions> suggestions =
              snapshot.data ?? const <DayRecipeSuggestions>[];

          if (suggestions.isEmpty) {
            return const Center(
              child: Text('No days need suggestions.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: <Widget>[
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
              ...suggestions.map((DayRecipeSuggestions day) {
                final Recipe? selectedRecipe = _selected[day.weekday];

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '${_weekdayLabel(day.weekday)} — ${day.dishIdea}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...day.candidates.map((RecipeSuggestionCandidate candidate) {
                      final String key = _candidateKey(day.weekday, candidate);
                      final bool importing = _importingKeys.contains(key);
                      final bool selected = selectedRecipe != null &&
                          selectedRecipe.sourceUrl.toString() ==
                              candidate.openUri.toString();

                      return Card(
                        child: ListTile(
                          title: Text(candidate.title),
                          subtitle: Text(
                            selected
                                ? '${candidate.subtitle}\nImported: ${selectedRecipe.title}'
                                : candidate.subtitle,
                          ),
                          isThreeLine: selected,
                          leading: importing
                              ? const SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
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
                            onPressed: () => _openRecipeInBrowser(candidate),
                          ),
                          onTap: importing
                              ? null
                              : () => _importCandidate(
                                    day.weekday,
                                    candidate,
                                  ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

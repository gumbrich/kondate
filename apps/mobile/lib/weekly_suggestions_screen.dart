import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

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

  final Map<WeekdayDe, RecipeSuggestionCandidate> _selected =
      <WeekdayDe, RecipeSuggestionCandidate>{};

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

  Future<void> _openRecipe(RecipeSuggestionCandidate candidate) async {
    await launchUrl(
      candidate.openUri,
      mode: LaunchMode.externalApplication,
    );
  }

  void _confirm() {
    Navigator.of(context)
        .pop<Map<WeekdayDe, RecipeSuggestionCandidate>>(_selected);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Recipe suggestions'),
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _confirm,
          ),
        ],
      ),
      body: FutureBuilder<List<DayRecipeSuggestions>>(
        future: _future,
        builder: (
          BuildContext context,
          AsyncSnapshot<List<DayRecipeSuggestions>> snapshot,
        ) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final List<DayRecipeSuggestions> suggestions = snapshot.data!;

          if (suggestions.isEmpty) {
            return const Center(
              child: Text('No days need suggestions.'),
            );
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: suggestions.map((DayRecipeSuggestions day) {
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
                    final bool selected =
                        _selected[day.weekday]?.openUri.toString() ==
                            candidate.openUri.toString();

                    return Card(
                      child: ListTile(
                        title: Text(candidate.title),
                        subtitle: Text(candidate.subtitle),
                        leading: Icon(
                          selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_off,
                        ),
                        onTap: () {
                          setState(() {
                            _selected[day.weekday] = candidate;
                          });
                        },
                        trailing: IconButton(
                          icon: const Icon(Icons.open_in_new),
                          onPressed: () => _openRecipe(candidate),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }
}

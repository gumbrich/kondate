import 'package:core/core.dart';
import 'package:flutter/material.dart';

class WeeklyPlanSection extends StatelessWidget {
  final MealPlanWeek mealPlan;
  final List<Recipe> recipes;
  final void Function(WeekdayDe weekday) onEdit;
  final void Function(WeekdayDe weekday) onClear;

  const WeeklyPlanSection({
    super.key,
    required this.mealPlan,
    required this.recipes,
    required this.onEdit,
    required this.onClear,
  });

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

  Recipe? _findRecipe(String? id) {
    if (id == null) return null;
    try {
      return recipes.firstWhere((Recipe r) => r.id == id);
    } catch (_) {
      return null;
    }
  }

  String _subtitle(MealPlanEntry entry) {
    final Recipe? recipe = _findRecipe(entry.recipeId);

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

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Weekly plan',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        ...WeekdayDe.values.map((WeekdayDe weekday) {
          final MealPlanEntry entry =
              mealPlan.entryFor(weekday) ?? MealPlanEntry(weekday: weekday);

          final bool hasAnything =
              (entry.dishIdea?.trim().isNotEmpty ?? false) ||
              entry.recipeId != null;

          return Card(
            child: ListTile(
              title: Text(_weekdayLabel(weekday)),
              subtitle: Text(_subtitle(entry)),
              onTap: () => onEdit(weekday),
              trailing: hasAnything
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => onClear(weekday),
                    )
                  : const Icon(Icons.edit),
            ),
          );
        }),
      ],
    );
  }
}

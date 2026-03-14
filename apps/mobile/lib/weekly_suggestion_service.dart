import 'package:core/core.dart';
import 'meal_plan_suggestion_models.dart';
import 'recipe_search_provider.dart';

class WeeklySuggestionService {
  final RecipeSearchProvider recipeSearchProvider;

  const WeeklySuggestionService({
    required this.recipeSearchProvider,
  });

  Future<List<DayRecipeSuggestions>> suggestForMealPlan({
    required MealPlanWeek mealPlan,
    required List<String> trustedSites,
    required int topN,
  }) async {
    final List<DayRecipeSuggestions> result = [];

    for (final weekday in WeekdayDe.values) {
      final entry = mealPlan.entryFor(weekday);

      if (entry == null) continue;
      if (entry.recipeId != null) continue;
      if (entry.dishIdea == null) continue;

      final String dishIdea = entry.dishIdea!.trim();
      if (dishIdea.isEmpty) continue;

      final candidates = await recipeSearchProvider.search(
        dishIdea: dishIdea,
        trustedSites: trustedSites,
        topN: topN,
      );

      result.add(
        DayRecipeSuggestions(
          weekday: weekday,
          dishIdea: dishIdea,
          candidates: candidates,
        ),
      );
    }

    return result;
  }
}

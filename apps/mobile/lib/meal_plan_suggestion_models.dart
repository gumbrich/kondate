import 'package:core/core.dart';

import 'recipe_search_provider.dart';

class DayRecipeSuggestions {
  final WeekdayDe weekday;
  final String dishIdea;
  final List<RecipeSuggestionCandidate> candidates;

  const DayRecipeSuggestions({
    required this.weekday,
    required this.dishIdea,
    required this.candidates,
  });
}

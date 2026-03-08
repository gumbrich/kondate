class RecipeSuggestionCandidate {
  final String title;
  final String subtitle;
  final String domain;
  final Uri searchUri;

  const RecipeSuggestionCandidate({
    required this.title,
    required this.subtitle,
    required this.domain,
    required this.searchUri,
  });
}

abstract class RecipeSearchProvider {
  Future<List<RecipeSuggestionCandidate>> search({
    required String dishIdea,
    required List<String> trustedSites,
    required int topN,
  });
}

class MockRecipeSearchProvider implements RecipeSearchProvider {
  const MockRecipeSearchProvider();

  @override
  Future<List<RecipeSuggestionCandidate>> search({
    required String dishIdea,
    required List<String> trustedSites,
    required int topN,
  }) async {
    final List<RecipeSuggestionCandidate> candidates =
        <RecipeSuggestionCandidate>[];

    for (final String domain in trustedSites.take(topN)) {
      candidates.add(
        RecipeSuggestionCandidate(
          title: '${_titleCase(dishIdea)} auf $domain',
          subtitle: 'Öffne Suchergebnisse und wähle dann dein Rezept',
          domain: domain,
          searchUri: Uri.https(
            'www.google.com',
            '/search',
            <String, String>{
              'q': 'site:$domain $dishIdea rezept',
            },
          ),
        ),
      );
    }

    return candidates;
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

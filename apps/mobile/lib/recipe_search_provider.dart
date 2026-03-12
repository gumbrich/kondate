import 'backend_api_models.dart';

class RecipeSuggestionCandidate {
  final String title;
  final String subtitle;
  final String domain;
  final Uri openUri;
  final double? score;

  const RecipeSuggestionCandidate({
    required this.title,
    required this.subtitle,
    required this.domain,
    required this.openUri,
    this.score,
  });

  factory RecipeSuggestionCandidate.fromSearchResult(
    RecipeSearchResult result,
  ) {
    return RecipeSuggestionCandidate(
      title: result.title,
      subtitle: result.subtitle ?? 'Öffne das Rezept im Browser',
      domain: result.domain,
      openUri: Uri.parse(result.url),
      score: result.score,
    );
  }
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
    final RecipeSearchRequest request = RecipeSearchRequest(
      dishIdea: dishIdea,
      trustedSites: trustedSites,
      topN: topN,
    );

    final RecipeSearchResponse response = _mockSearch(request);

    return response.results
        .map(RecipeSuggestionCandidate.fromSearchResult)
        .toList();
  }

  RecipeSearchResponse _mockSearch(RecipeSearchRequest request) {
    final List<RecipeSearchResult> results = <RecipeSearchResult>[];

    int rank = 0;
    for (final String domain in request.trustedSites.take(request.topN)) {
      rank += 1;

      results.add(
        RecipeSearchResult(
          title: '${_titleCase(request.dishIdea)} auf $domain',
          domain: domain,
          url: Uri.https(
            'www.google.com',
            '/search',
            <String, String>{
              'q': 'site:$domain ${request.dishIdea} rezept',
            },
          ).toString(),
          subtitle: 'Mock-Treffer $rank • Öffne Suchergebnisse im Browser',
          score: (request.topN - rank + 1).toDouble(),
        ),
      );
    }

    return RecipeSearchResponse(results: results);
  }

  String _titleCase(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

class HttpRecipeSearchProvider implements RecipeSearchProvider {
  final Uri baseUri;

  const HttpRecipeSearchProvider({
    required this.baseUri,
  });

  @override
  Future<List<RecipeSuggestionCandidate>> search({
    required String dishIdea,
    required List<String> trustedSites,
    required int topN,
  }) async {
    final RecipeSearchRequest request = RecipeSearchRequest(
      dishIdea: dishIdea,
      trustedSites: trustedSites,
      topN: topN,
    );

    throw UnimplementedError(
      'Backend search not wired yet. Later this will POST '
      '${request.toJson()} to $baseUri/search and parse a '
      'RecipeSearchResponse.',
    );
  }
}

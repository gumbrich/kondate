import 'dart:convert';
import 'dart:io';

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
      subtitle: result.subtitle ?? 'Open recipe in browser',
      domain: result.domain,
      openUri: Uri.parse(result.url),
      score: result.score,
    );
  }
}

class RecipeSearchDebugResult {
  final List<RecipeSuggestionCandidate> candidates;
  final List<String> debugLines;

  const RecipeSearchDebugResult({
    required this.candidates,
    required this.debugLines,
  });
}

abstract class RecipeSearchProvider {
  Future<List<RecipeSuggestionCandidate>> search({
    required String dishIdea,
    required List<String> trustedSites,
    required int topN,
  });

  Future<RecipeSearchDebugResult> searchDebug({
    required String dishIdea,
    required List<String> trustedSites,
    required int topN,
  });
}

class MockRecipeSearchProvider implements RecipeSearchProvider {
  // Keep the old name so the rest of the app does not need changes.
  // It now calls the local backend.
  const MockRecipeSearchProvider();

  static final Uri _baseUri = Uri.parse('http://127.0.0.1:8000');

  @override
  Future<List<RecipeSuggestionCandidate>> search({
    required String dishIdea,
    required List<String> trustedSites,
    required int topN,
  }) async {
    final RecipeSearchDebugResult debug = await searchDebug(
      dishIdea: dishIdea,
      trustedSites: trustedSites,
      topN: topN,
    );
    return debug.candidates;
  }

  @override
  Future<RecipeSearchDebugResult> searchDebug({
    required String dishIdea,
    required List<String> trustedSites,
    required int topN,
  }) async {
    final HttpClient client = HttpClient();

    try {
      final HttpClientRequest request =
          await client.postUrl(_baseUri.resolve('/search'));
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(<String, dynamic>{
          'dishIdea': dishIdea,
          'trustedSites': trustedSites,
          'topN': topN,
        }),
      );

      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return RecipeSearchDebugResult(
          candidates: const <RecipeSuggestionCandidate>[],
          debugLines: <String>[
            'backend returned status ${response.statusCode}',
            body,
          ],
        );
      }

      final Map<String, dynamic> json =
          jsonDecode(body) as Map<String, dynamic>;
      final RecipeSearchResponse parsed = RecipeSearchResponse.fromJson(json);

      return RecipeSearchDebugResult(
        candidates: parsed.results
            .map(RecipeSuggestionCandidate.fromSearchResult)
            .toList(),
        debugLines: <String>[
          'backend ok',
          'received ${parsed.results.length} direct results',
        ],
      );
    } catch (e) {
      return RecipeSearchDebugResult(
        candidates: const <RecipeSuggestionCandidate>[],
        debugLines: <String>[
          'backend request failed',
          e.toString(),
        ],
      );
    } finally {
      client.close(force: true);
    }
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
    final RecipeSearchDebugResult debug = await searchDebug(
      dishIdea: dishIdea,
      trustedSites: trustedSites,
      topN: topN,
    );
    return debug.candidates;
  }

  @override
  Future<RecipeSearchDebugResult> searchDebug({
    required String dishIdea,
    required List<String> trustedSites,
    required int topN,
  }) async {
    final HttpClient client = HttpClient();

    try {
      final HttpClientRequest request = await client.postUrl(
        baseUri.resolve('/search'),
      );
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(<String, dynamic>{
          'dishIdea': dishIdea,
          'trustedSites': trustedSites,
          'topN': topN,
        }),
      );

      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        return RecipeSearchDebugResult(
          candidates: const <RecipeSuggestionCandidate>[],
          debugLines: <String>[
            'backend returned status ${response.statusCode}',
            body,
          ],
        );
      }

      final Map<String, dynamic> json =
          jsonDecode(body) as Map<String, dynamic>;
      final RecipeSearchResponse parsed = RecipeSearchResponse.fromJson(json);

      return RecipeSearchDebugResult(
        candidates: parsed.results
            .map(RecipeSuggestionCandidate.fromSearchResult)
            .toList(),
        debugLines: <String>[
          'backend ok',
          'received ${parsed.results.length} direct results',
        ],
      );
    } catch (e) {
      return RecipeSearchDebugResult(
        candidates: const <RecipeSuggestionCandidate>[],
        debugLines: <String>[
          'backend request failed',
          e.toString(),
        ],
      );
    } finally {
      client.close(force: true);
    }
  }
}

import 'dart:convert';
import 'dart:io';

import 'backend_config.dart';

class RecipeSuggestionCandidate {
  final String title;
  final Uri openUri;
  final String subtitle;

  const RecipeSuggestionCandidate({
    required this.title,
    required this.openUri,
    required this.subtitle,
  });
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
  const MockRecipeSearchProvider();

  @override
  Future<List<RecipeSuggestionCandidate>> search({
    required String dishIdea,
    required List<String> trustedSites,
    required int topN,
  }) async {
    return <RecipeSuggestionCandidate>[
      RecipeSuggestionCandidate(
        title: '$dishIdea (mock)',
        openUri: Uri.parse('https://example.com'),
        subtitle: 'example.com',
      ),
    ];
  }

  @override
  Future<RecipeSearchDebugResult> searchDebug({
    required String dishIdea,
    required List<String> trustedSites,
    required int topN,
  }) async {
    final List<RecipeSuggestionCandidate> candidates = await search(
      dishIdea: dishIdea,
      trustedSites: trustedSites,
      topN: topN,
    );

    return RecipeSearchDebugResult(
      candidates: candidates,
      debugLines: const <String>[
        'mock provider active',
      ],
    );
  }
}

class BackendRecipeSearchProvider implements RecipeSearchProvider {
  static final Uri _baseUri = Uri.parse(backendBaseUrl);

  const BackendRecipeSearchProvider();

  @override
  Future<List<RecipeSuggestionCandidate>> search({
    required String dishIdea,
    required List<String> trustedSites,
    required int topN,
  }) async {
    final RecipeSearchDebugResult result = await searchDebug(
      dishIdea: dishIdea,
      trustedSites: trustedSites,
      topN: topN,
    );
    return result.candidates;
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
            'backend request failed',
            'HTTP ${response.statusCode}',
            body,
          ],
        );
      }

      final Map<String, dynamic> decoded =
          jsonDecode(body) as Map<String, dynamic>;

      final List<dynamic> rawResults =
          (decoded['results'] as List<dynamic>? ?? const <dynamic>[]);

      final List<RecipeSuggestionCandidate> candidates = rawResults
          .whereType<Map<String, dynamic>>()
          .map((Map<String, dynamic> item) {
            final String title =
                (item['title'] as String?)?.trim().isNotEmpty == true
                    ? item['title'] as String
                    : 'Untitled recipe';

            final String url = (item['url'] as String?)?.trim() ?? '';

            final String domain =
                (item['domain'] as String?)?.trim().isNotEmpty == true
                    ? item['domain'] as String
                    : '';

            final String subtitle =
                (item['subtitle'] as String?)?.trim().isNotEmpty == true
                    ? item['subtitle'] as String
                    : domain;

            return RecipeSuggestionCandidate(
              title: title,
              openUri: Uri.parse(url),
              subtitle: subtitle,
            );
          })
          .where((RecipeSuggestionCandidate c) {
            return c.openUri.hasScheme && c.openUri.host.isNotEmpty;
          })
          .toList();

      return RecipeSearchDebugResult(
        candidates: candidates,
        debugLines: <String>[
          'backend request ok',
          'trusted sites: ${trustedSites.join(', ')}',
          'received ${candidates.length} result(s)',
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

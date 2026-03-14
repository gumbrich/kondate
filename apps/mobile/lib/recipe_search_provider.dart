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

/// Kept under the old name so main.dart does not need to change.
/// This now performs real search against DuckDuckGo HTML results
/// and falls back to plain site-search links if needed.
///
/// Note: this implementation is intended for desktop/mobile.
/// It uses dart:io and is not suitable for Flutter Web.
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

    try {
      final RecipeSearchResponse response = await _realSearch(request);
      if (response.results.isNotEmpty) {
        return response.results
            .map(RecipeSuggestionCandidate.fromSearchResult)
            .toList();
      }
    } catch (_) {
      // fall through to fallback
    }

    final RecipeSearchResponse fallback = _fallbackSearch(request);
    return fallback.results
        .map(RecipeSuggestionCandidate.fromSearchResult)
        .toList();
  }

  Future<RecipeSearchResponse> _realSearch(RecipeSearchRequest request) async {
    final List<RecipeSearchResult> results = <RecipeSearchResult>[];
    final Set<String> seenUrls = <String>{};

    int rank = 0;

    for (final String domain in request.trustedSites) {
      if (results.length >= request.topN) break;

      final List<RecipeSearchResult> domainResults = await _searchSingleDomain(
        dishIdea: request.dishIdea,
        domain: domain,
        wanted: request.topN - results.length,
      );

      for (final RecipeSearchResult result in domainResults) {
        if (seenUrls.add(result.url)) {
          rank += 1;
          results.add(
            RecipeSearchResult(
              title: result.title,
              domain: result.domain,
              url: result.url,
              subtitle: result.subtitle,
              score: (request.topN - rank + 1).toDouble(),
            ),
          );
        }

        if (results.length >= request.topN) {
          break;
        }
      }
    }

    return RecipeSearchResponse(results: results);
  }

  Future<List<RecipeSearchResult>> _searchSingleDomain({
    required String dishIdea,
    required String domain,
    required int wanted,
  }) async {
    final String query = 'site:$domain "$dishIdea" rezept';
    final Uri uri = Uri.https(
      'html.duckduckgo.com',
      '/html/',
      <String, String>{'q': query},
    );

    final String html = await _fetch(uri);
    final List<_HtmlSearchResult> parsed = _parseDuckDuckGoResults(html);

    final List<RecipeSearchResult> results = <RecipeSearchResult>[];

    for (final _HtmlSearchResult item in parsed) {
      final Uri? targetUri = _extractTargetUri(item.href);
      if (targetUri == null) continue;

      final String host = targetUri.host.toLowerCase();
      if (!_hostMatchesDomain(host, domain.toLowerCase())) continue;

      final String title = _cleanTitle(item.title);
      if (title.isEmpty) continue;

      results.add(
        RecipeSearchResult(
          title: title,
          domain: domain,
          url: targetUri.toString(),
          subtitle: 'Suchtreffer von $domain',
          score: null,
        ),
      );

      if (results.length >= wanted) {
        break;
      }
    }

    return results;
  }

  Future<String> _fetch(Uri uri) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) '
        'AppleWebKit/537.36 (KHTML, like Gecko) '
        'Chrome/122.0.0.0 Safari/537.36',
      );
      request.headers.set(
        HttpHeaders.acceptHeader,
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      );

      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException(
          'Search request failed with ${response.statusCode}',
          uri: uri,
        );
      }

      return body;
    } finally {
      client.close(force: true);
    }
  }

  List<_HtmlSearchResult> _parseDuckDuckGoResults(String html) {
    final RegExp anchorPattern = RegExp(
      r'<a[^>]*class="[^"]*result__a[^"]*"[^>]*href="([^"]+)"[^>]*>(.*?)</a>',
      caseSensitive: false,
      dotAll: true,
    );

    final List<_HtmlSearchResult> results = <_HtmlSearchResult>[];

    for (final RegExpMatch match in anchorPattern.allMatches(html)) {
      final String href = match.group(1) ?? '';
      final String rawTitle = match.group(2) ?? '';

      if (href.isEmpty || rawTitle.isEmpty) continue;

      results.add(
        _HtmlSearchResult(
          href: _decodeHtmlEntities(href),
          title: _stripTags(_decodeHtmlEntities(rawTitle)).trim(),
        ),
      );
    }

    return results;
  }

  Uri? _extractTargetUri(String href) {
    if (href.isEmpty) return null;

    final String normalized = href.startsWith('//') ? 'https:$href' : href;
    final Uri? parsed = Uri.tryParse(normalized);
    if (parsed == null) return null;

    if (parsed.host.contains('duckduckgo.com')) {
      final String? uddg = parsed.queryParameters['uddg'];
      if (uddg != null && uddg.isNotEmpty) {
        final Uri? decoded = Uri.tryParse(Uri.decodeComponent(uddg));
        if (decoded != null) {
          return decoded;
        }
      }
    }

    return parsed;
  }

  bool _hostMatchesDomain(String host, String domain) {
    return host == domain || host.endsWith('.$domain');
  }

  String _cleanTitle(String title) {
    return title.replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  String _stripTags(String input) {
    return input.replaceAll(RegExp(r'<[^>]+>'), '');
  }

  String _decodeHtmlEntities(String input) {
    return input
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&uuml;', 'ü')
        .replaceAll('&Uuml;', 'Ü')
        .replaceAll('&ouml;', 'ö')
        .replaceAll('&Ouml;', 'Ö')
        .replaceAll('&auml;', 'ä')
        .replaceAll('&Auml;', 'Ä')
        .replaceAll('&szlig;', 'ß');
  }

  RecipeSearchResponse _fallbackSearch(RecipeSearchRequest request) {
    final List<RecipeSearchResult> results = <RecipeSearchResult>[];

    int rank = 0;
    for (final String domain in request.trustedSites.take(request.topN)) {
      rank += 1;

      final Uri searchUri = Uri.https(
        'www.google.com',
        '/search',
        <String, String>{
          'q': 'site:$domain ${request.dishIdea} rezept',
        },
      );

      results.add(
        RecipeSearchResult(
          title: '${_titleCase(request.dishIdea)} auf $domain',
          domain: domain,
          url: searchUri.toString(),
          subtitle: 'Fallback-Suche auf $domain',
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

class _HtmlSearchResult {
  final String href;
  final String title;

  const _HtmlSearchResult({
    required this.href,
    required this.title,
  });
}

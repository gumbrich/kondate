class RecipeSearchRequest {
  final String dishIdea;
  final List<String> trustedSites;
  final int topN;

  const RecipeSearchRequest({
    required this.dishIdea,
    required this.trustedSites,
    required this.topN,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'dishIdea': dishIdea,
      'trustedSites': trustedSites,
      'topN': topN,
    };
  }

  factory RecipeSearchRequest.fromJson(Map<String, dynamic> json) {
    return RecipeSearchRequest(
      dishIdea: json['dishIdea'] as String? ?? '',
      trustedSites: (json['trustedSites'] as List<dynamic>? ?? <dynamic>[])
          .map((dynamic e) => e.toString())
          .toList(),
      topN: json['topN'] as int? ?? 3,
    );
  }
}

class RecipeSearchResult {
  final String title;
  final String domain;
  final String url;
  final String? subtitle;
  final double? score;

  const RecipeSearchResult({
    required this.title,
    required this.domain,
    required this.url,
    this.subtitle,
    this.score,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'title': title,
      'domain': domain,
      'url': url,
      'subtitle': subtitle,
      'score': score,
    };
  }

  factory RecipeSearchResult.fromJson(Map<String, dynamic> json) {
    return RecipeSearchResult(
      title: json['title'] as String? ?? '',
      domain: json['domain'] as String? ?? '',
      url: json['url'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      score: (json['score'] as num?)?.toDouble(),
    );
  }
}

class RecipeSearchResponse {
  final List<RecipeSearchResult> results;

  const RecipeSearchResponse({
    required this.results,
  });

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'results': results.map((RecipeSearchResult r) => r.toJson()).toList(),
    };
  }

  factory RecipeSearchResponse.fromJson(Map<String, dynamic> json) {
    final List<dynamic> raw = json['results'] as List<dynamic>? ?? <dynamic>[];

    return RecipeSearchResponse(
      results: raw
          .whereType<Map<String, dynamic>>()
          .map(RecipeSearchResult.fromJson)
          .toList(),
    );
  }
}

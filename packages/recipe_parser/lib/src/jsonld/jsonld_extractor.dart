import 'dart:convert';

class JsonLdExtractor {
  static final RegExp _re = RegExp(
    '<script[^>]+type=["\\\']application/ld\\+json["\\\'][^>]*>(.*?)</script>',
    caseSensitive: false,
    dotAll: true,
  );

  List<dynamic> extractJsonLdObjects(String html) {
    final List<dynamic> out = <dynamic>[];

    for (final RegExpMatch m in _re.allMatches(html)) {
      final String? raw = m.group(1);
      if (raw == null) continue;

      final String cleaned = _cleanJsonLd(raw);
      if (cleaned.isEmpty) continue;

      try {
        out.add(jsonDecode(cleaned));
      } catch (_) {
        // Ignore invalid JSON-LD blocks.
      }
    }

    return out;
  }

  Map<String, dynamic>? findRecipeObject(List<dynamic> jsonLd) {
    Map<String, dynamic>? recipe;

    void visit(dynamic node) {
      if (node == null || recipe != null) return;

      if (node is Map) {
        final Map<String, dynamic> map = _toStringKeyedMap(node);

        if (_isRecipeType(map['@type'])) {
          recipe = map;
          return;
        }

        final dynamic graph = map['@graph'];
        if (graph != null) {
          visit(graph);
        }

        for (final dynamic value in map.values) {
          visit(value);
        }
      } else if (node is List) {
        for (final dynamic value in node) {
          visit(value);
          if (recipe != null) return;
        }
      }
    }

    for (final dynamic blob in jsonLd) {
      visit(blob);
      if (recipe != null) break;
    }

    return recipe;
  }

  bool _isRecipeType(dynamic typeValue) {
    if (typeValue == null) return false;

    if (typeValue is String) {
      return _normalizeType(typeValue) == 'recipe';
    }

    if (typeValue is List) {
      for (final dynamic item in typeValue) {
        if (item is String && _normalizeType(item) == 'recipe') {
          return true;
        }
      }
    }

    return false;
  }

  String _normalizeType(String value) {
    final String trimmed = value.trim().toLowerCase();

    if (trimmed.endsWith('/recipe')) return 'recipe';
    if (trimmed.endsWith('#recipe')) return 'recipe';

    return trimmed;
  }

  Map<String, dynamic> _toStringKeyedMap(Map input) {
    final Map<String, dynamic> out = <String, dynamic>{};

    input.forEach((dynamic key, dynamic value) {
      out[key.toString()] = value;
    });

    return out;
  }

  String _cleanJsonLd(String raw) {
    return raw
        .replaceAll(RegExp(r'^\s*<!--'), '')
        .replaceAll(RegExp(r'-->\s*$'), '')
        .trim();
  }
}

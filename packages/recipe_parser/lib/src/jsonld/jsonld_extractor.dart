import 'dart:convert';

class JsonLdExtractor {
  // Matches <script type="application/ld+json"> ... </script>
  // We avoid raw strings here to sidestep any quoting/escaping issues.
  static final RegExp _re = RegExp(
    '<script[^>]+type=["\\\']application/ld\\+json["\\\'][^>]*>(.*?)</script>',
    caseSensitive: false,
    dotAll: true,
  );

  List<dynamic> extractJsonLdObjects(String html) {
    final out = <dynamic>[];
    for (final m in _re.allMatches(html)) {
      final raw = m.group(1);
      if (raw == null) continue;
      try {
        out.add(jsonDecode(raw.trim()));
      } catch (_) {
        // ignore invalid JSON-LD
      }
    }
    return out;
  }

  Map<String, dynamic>? findRecipeObject(List<dynamic> jsonLd) {
    Map<String, dynamic>? recipe;

    void visit(dynamic node) {
      if (node == null || recipe != null) return;

      if (node is Map<String, dynamic>) {
        final type = node['@type'];
        final isRecipe =
            type == 'Recipe' || (type is List && type.contains('Recipe'));
        if (isRecipe) {
          recipe = node;
          return;
        }

        if (node.containsKey('@graph')) {
          visit(node['@graph']);
        }
        for (final v in node.values) {
          visit(v);
        }
      } else if (node is List) {
        for (final v in node) {
          visit(v);
        }
      }
    }

    for (final blob in jsonLd) {
      visit(blob);
      if (recipe != null) break;
    }
    return recipe;
  }
}

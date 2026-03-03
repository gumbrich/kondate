import 'dart:io';
import 'package:recipe_parser/src/jsonld/jsonld_recipe_parser.dart';
import 'package:test/test.dart';

void main() {
  test('parses JSON-LD recipe from HTML fixture', () async {
    final html = await File('test/fixtures/recipe_jsonld_de.html').readAsString();
    final parser = JsonLdRecipeParser();

    final r = parser.parseFromHtml(html);
    expect(r.title, 'Test Rezept');
    expect(r.servings, 4);
    expect(r.ingredientLines.length, 5);
  });
}

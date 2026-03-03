import 'dart:io';

import 'package:core/core.dart';
import 'package:recipe_parser/src/kondate_recipe_importer.dart';
import 'package:recipe_parser/src/http/page_fetcher.dart';
import 'package:test/test.dart';

class FakeFetcher extends PageFetcher {
  final String html;
  FakeFetcher(this.html);

  @override
  Future<String> fetchHtml(Uri url) async => html;
}

void main() {
  test('importer parses quantities using German rules', () async {
    final html = await File('test/fixtures/recipe_jsonld_de.html').readAsString();
    final importer = KondateRecipeImporter(fetcher: FakeFetcher(html));

    final recipe = await importer.importRecipe(
      url: Uri.parse('https://example.com/test'),
      id: 'r1',
    );

    expect(recipe.title, 'Test Rezept');
    expect(recipe.defaultServings, 4);

    final q0 = recipe.ingredients[0].quantity!;
    expect(q0.value, closeTo(1.5, 1e-9));
    expect(q0.unit, Unit.tablespoon);

    final q1 = recipe.ingredients[1].quantity!;
    expect(q1.value, 2);
    expect(q1.unit, Unit.can);

    expect(recipe.ingredients[4].quantity, isNull); // "Salz nach Geschmack"
  });
}

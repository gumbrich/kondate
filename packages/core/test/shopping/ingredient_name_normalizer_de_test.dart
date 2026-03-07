import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  test('normalizes singular/plural', () {
    expect(
      IngredientNameNormalizerDe.normalize('2 Zwiebeln'),
      'zwiebel',
    );
    expect(
      IngredientNameNormalizerDe.normalize('1 Zwiebel'),
      'zwiebel',
    );
    expect(
      IngredientNameNormalizerDe.normalize('3 Tomaten'),
      'tomate',
    );
  });

  test('normalizes umlaut spellings', () {
    expect(
      IngredientNameNormalizerDe.normalize('1 EL Olivenoel'),
      'olivenöl',
    );
    expect(
      IngredientNameNormalizerDe.normalize('1 EL Olivenöl'),
      'olivenöl',
    );
  });

  test('removes simple descriptors', () {
    expect(
      IngredientNameNormalizerDe.normalize('2 frische Tomaten'),
      'tomate',
    );
    expect(
      IngredientNameNormalizerDe.normalize('1 fein gehackte Zwiebeln'),
      'gehackte zwiebel',
    );
  });

  test('normalizes spring onions plural', () {
    expect(
      IngredientNameNormalizerDe.normalize('2 Frühlingszwiebeln'),
      'frühlingszwiebel',
    );
  });
}

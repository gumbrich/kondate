import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  test('parses comma decimal + EL', () {
    final q = QuantityParserDe.parseLeadingQuantity('1,5 EL Olivenöl');
    expect(q, isNotNull);
    expect(q!.value, closeTo(1.5, 1e-9));
    expect(q.unit, Unit.tablespoon);
  });

  test('parses integer + plural unit', () {
    final q = QuantityParserDe.parseLeadingQuantity('2 Dosen Tomaten');
    expect(q, isNotNull);
    expect(q!.value, 2);
    expect(q.unit, Unit.can);
  });

  test('parses range by taking first number', () {
    final q = QuantityParserDe.parseLeadingQuantity('3-4 Zehen Knoblauch');
    expect(q, isNotNull);
    expect(q!.value, 3);
    expect(q.unit, Unit.clove);
  });

  test('returns null if no leading number', () {
    final q = QuantityParserDe.parseLeadingQuantity('Salz nach Geschmack');
    expect(q, isNull);
  });

  test('parses grams', () {
    final q = QuantityParserDe.parseLeadingQuantity('250 g Mehl');
    expect(q, isNotNull);
    expect(q!.value, 250);
    expect(q.unit, Unit.gram);
  });
}

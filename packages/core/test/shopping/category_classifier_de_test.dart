import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  test('classifies common items', () {
    expect(CategoryClassifierDe.classify('zwiebeln'), CategoryDe.gemuese);
    expect(CategoryClassifierDe.classify('milch'), CategoryDe.milchprodukte);
    expect(CategoryClassifierDe.classify('salz'), CategoryDe.gewuerze);
    expect(CategoryClassifierDe.classify('olivenöl'), CategoryDe.oeleSaucen);
  });
}

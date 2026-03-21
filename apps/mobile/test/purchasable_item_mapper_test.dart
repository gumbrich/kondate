import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/purchasable_item.dart';
import 'package:mobile/purchasable_item_mapper.dart';

void main() {
  group('PurchasableItemMapper', () {
    test('mapped Tomatenprodukt sinnvoll', () {
      final item = PurchasableItemMapper.fromIngredient(
        quantity: 2,
        unit: 'Dose',
        name: 'Stückige Tomaten',
      );

      expect(item.category, PurchasableCategory.konserven);
      expect(item.shopSearchQuery, 'stückige tomaten 400g');
      expect(item.preferredPackage, 'Dose 400 g');
    });

    test('mapped Hackfleisch sinnvoll', () {
      final item = PurchasableItemMapper.fromIngredient(
        quantity: 500,
        unit: 'g',
        name: 'Gemischtes Hackfleisch',
      );

      expect(item.category, PurchasableCategory.fleisch);
      expect(item.shopSearchQuery, 'gemischtes hackfleisch 500g');
      expect(item.preferredPackage, 'Packung 500 g');
    });

    test('mapped Milch sinnvoll', () {
      final item = PurchasableItemMapper.fromIngredient(
        quantity: 1000,
        unit: 'ml',
        name: 'Milch',
      );

      expect(item.category, PurchasableCategory.milchprodukte);
      expect(item.shopSearchQuery, 'milch 1l');
      expect(item.preferredPackage, '1 l');
    });
  });
}

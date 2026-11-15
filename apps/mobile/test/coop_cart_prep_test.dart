import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/coop_basket_service.dart';
import 'package:mobile/coop_cart_prep_screen.dart';
import 'package:mobile/coop_saved_product.dart';
import 'package:mobile/coop_saved_products_screen.dart';
import 'package:mobile/coop_saved_products_store.dart';
import 'package:mobile/purchasable_item_mapper.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const feta = CoopSavedProduct(
    canonicalKey: 'feta',
    productLabel: 'Test Feta 200 g',
    productUrl: 'https://www.coop.ch/de/p/12345',
  );
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'missing products block; chosen product persists and target reaches assistant',
    (tester) async {
      List<CoopBasketItem>? received;
      await tester.pumpWidget(
        MaterialApp(
          home: CoopCartPrepScreen(
            items: [
              PurchasableItemMapper.fromIngredient(
                name: 'Feta',
                quantity: 200,
                unit: 'g',
              ),
            ],
            chooseProduct: (_) async => feta,
            assistantBuilder: (items) {
              received = items;
              return const Scaffold(body: Text('Test assistant'));
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coop-Assistent starten'));
      await tester.pumpAndSettle();
      expect(find.text('Für jede Zutat ein Produkt wählen'), findsOneWidget);
      expect(received, isNull);
      await tester.tap(find.text('Produkte auswählen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Coop-Produkt auswählen'));
      await tester.pumpAndSettle();
      expect(
        (await CoopSavedProductsStore().loadSavedProducts())['feta']
            ?.productUrl,
        feta.productUrl,
      );
      await tester.tap(find.text('Coop-Assistent starten'));
      await tester.pumpAndSettle();
      expect(find.text('Feta: 200 g'), findsOneWidget);
      await tester.tap(find.byTooltip('Mehr Packungen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Assistent öffnen'));
      await tester.pumpAndSettle();
      expect(received!.single.targetQuantity, 2);
      expect(received!.single.product.productUrl, feta.productUrl);
    },
  );

  testWidgets('cancelled choice leaves mapping unresolved', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: CoopCartPrepScreen(
          items: [
            PurchasableItemMapper.fromIngredient(
              name: 'Feta',
              quantity: 200,
              unit: 'g',
            ),
          ],
          chooseProduct: (_) async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Coop-Produkt auswählen'));
    await tester.pumpAndSettle();
    expect(await CoopSavedProductsStore().loadSavedProducts(), isEmpty);
  });

  testWidgets(
    'duplicate SKUs share one target; unchecked unmapped item is excluded',
    (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await CoopSavedProductsStore().saveProduct(feta);
      List<CoopBasketItem>? received;
      await tester.pumpWidget(
        MaterialApp(
          home: CoopCartPrepScreen(
            items: [
              PurchasableItemMapper.fromIngredient(
                name: 'Feta',
                quantity: 200,
                unit: 'g',
              ),
              PurchasableItemMapper.fromIngredient(
                name: 'Feta',
                quantity: 100,
                unit: 'g',
              ),
              PurchasableItemMapper.fromIngredient(
                name: 'Wirz',
                quantity: 1,
                unit: 'Stk.',
              ),
            ],
            assistantBuilder: (items) {
              received = items;
              return const Scaffold();
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      final lastItem = find.byType(CheckboxListTile).last;
      await tester.ensureVisible(lastItem);
      await tester.tap(lastItem);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Coop-Assistent starten'));
      await tester.tap(find.text('Coop-Assistent starten'));
      await tester.pumpAndSettle();
      expect(find.text('Feta: 200 g\nFeta: 100 g'), findsOneWidget);
      expect(find.byTooltip('Mehr Packungen'), findsOneWidget);
      await tester.tap(find.text('Assistent öffnen'));
      await tester.pumpAndSettle();
      expect(received, hasLength(1));
    },
  );

  testWidgets('saved-product editor preserves arbitrary ingredient keys', (
    tester,
  ) async {
    await CoopSavedProductsStore().saveProduct(feta);
    await tester.pumpWidget(const MaterialApp(home: CoopSavedProductsScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Speichern'));
    await tester.pumpAndSettle();
    expect(
      (await CoopSavedProductsStore().loadSavedProducts())['feta']?.productUrl,
      feta.productUrl,
    );
  });
}

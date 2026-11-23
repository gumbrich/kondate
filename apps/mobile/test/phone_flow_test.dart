import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app_state.dart';
import 'package:mobile/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'phone: create recipe, plan meal, prepare ingredients without silent omissions',
    (tester) async {
      // Isolated preferences: never reads or overwrites a real household.
      SharedPreferences.setMockInitialValues({});
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const title = 'Kartoffel-Gemüse-Auflauf mit Feta und frischen Kräutern';
      await tester.pumpWidget(const KondateApp());
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rezept manuell erstellen'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Recipe title'),
        title,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Recipe servings'),
        '2.5',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Ingredients (one per line)'),
        '200 g Feta\n500 g Kartoffeln',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect((await KondateAppState.load()).recipes.single.title, title);
      await tester.ensureVisible(find.text('Montag'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Montag'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Dish idea'),
        'Auflauf',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(title).last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      final saved = await KondateAppState.load();
      expect(saved.selectedMealPlanRecipes().single.title, title);
      await tester.ensureVisible(find.text('Einkaufsliste öffnen'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Einkaufsliste öffnen'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Shop-Vorschau'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Warenkorb vorbereiten'));
      await tester.pumpAndSettle();
      expect(find.text('Ausgewählt: 2 von 2'), findsOneWidget);
      await tester.tap(find.text('Coop-Assistent starten'));
      await tester.pumpAndSettle();
      expect(find.text('Für jede Zutat ein Produkt wählen'), findsOneWidget);
      expect(find.textContaining('Noch offen:'), findsOneWidget);
      expect(
        find.textContaining('Noch offen:').evaluate().single.widget,
        isA<Text>().having(
          (text) => text.data,
          'unresolved ingredients',
          allOf(contains('Feta'), contains('Kartoffel')),
        ),
      );
      expect(tester.takeException(), isNull);
    },
  );
}

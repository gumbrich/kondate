import 'dart:convert';

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/app_state.dart';
import 'package:mobile/photo_week_plan.dart';
import 'package:mobile/photo_week_plan_screen.dart';
import 'package:mobile/week_plan_photo_source.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DeniedCamera extends WeekPlanPhotoSource {
  @override
  Future<Uint8List?> pick({required bool camera}) async {
    throw PlatformException(
      code: 'camera_denied',
      message: 'Kamerazugriff verweigert.',
    );
  }

  @override
  Future<void> cancel() async {}
}

void main() {
  testWidgets(
    'spelling suggestion changes draft only after a tap and does not select day',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoWeekPlanScreen(
            mealPlan: KondateAppState.initial().mealPlan,
            recipes: const [],
          ),
        ),
      );
      final field = find.byType(TextField).first;
      await tester.ensureVisible(field);
      await tester.enterText(field, 'Zitronenrisatho');
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Zitronenrisatho',
      );
      final suggestion = find.widgetWithText(ActionChip, 'Zitronenrisotto');
      await tester.ensureVisible(suggestion);
      await tester.tap(suggestion);
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(field).controller!.text,
        'Zitronenrisotto',
      );
      expect(
        tester
            .widget<CheckboxListTile>(find.byType(CheckboxListTile).first)
            .value,
        false,
      );
    },
  );
  final recipe = Recipe(
    id: 'old',
    title: 'Existing recipe',
    sourceUrl: Uri.parse('https://example.com/recipe'),
    defaultServings: 2,
    ingredients: const [],
  );
  final original = KondateAppState.initial()
      .addRecipe(recipe)
      .updateMealPlanEntry(
        weekday: WeekdayDe.montag,
        dishIdea: 'Pasta',
        recipeId: 'old',
      )
      .updateMealPlanEntry(
        weekday: WeekdayDe.dienstag,
        dishIdea: 'Soup',
        recipeId: 'old',
      );

  test(
    'photo merge preserves unselected days, recipes and settings; clears stale links',
    () async {
      SharedPreferences.setMockInitialValues({});
      final updated = original.applyPhotoMealIdeas({
        WeekdayDe.montag: '  Risotto  ',
        WeekdayDe.mittwoch: ' ',
        WeekdayDe.donnerstag: 'Salat',
      });
      expect(updated.mealPlan.entryFor(WeekdayDe.montag)?.dishIdea, 'Risotto');
      expect(updated.mealPlan.entryFor(WeekdayDe.montag)?.recipeId, isNull);
      expect(
        updated.mealPlan.entryFor(WeekdayDe.dienstag),
        same(original.mealPlan.entryFor(WeekdayDe.dienstag)),
      );
      expect(updated.mealPlan.entryFor(WeekdayDe.mittwoch), isNull);
      expect(updated.recipes, same(original.recipes));
      expect(updated.shoppingState, same(original.shoppingState));
      expect(updated.targetServings, original.targetServings);
      expect(updated.trustedSites, original.trustedSites);
      await updated.saveAll();
      final reloaded = await KondateAppState.load();
      expect(reloaded.mealPlan.entryFor(WeekdayDe.montag)?.dishIdea, 'Risotto');
      expect(reloaded.mealPlan.entryFor(WeekdayDe.montag)?.recipeId, isNull);
      expect(reloaded.recipes.single.id, 'old');
      expect(original.mealPlan.entryFor(WeekdayDe.montag)?.dishIdea, 'Pasta');
    },
  );

  test('unchanged meal keeps its recipe link', () {
    expect(
      original
          .applyPhotoMealIdeas({WeekdayDe.montag: ' Pasta '})
          .mealPlan
          .entryFor(WeekdayDe.montag)
          ?.recipeId,
      'old',
    );
  });

  testWidgets(
    'denied camera leaves manual editing available and does not alter saved state',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoWeekPlanScreen(
            mealPlan: original.mealPlan,
            recipes: original.recipes,
            photoSource: DeniedCamera(),
          ),
        ),
      );
      await tester.tap(find.text('Foto aufnehmen'));
      await tester.pumpAndSettle();
      expect(find.text('Kamerazugriff verweigert.'), findsOneWidget);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).enabled,
        true,
      );
      expect(original.mealPlan.entryFor(WeekdayDe.montag)?.dishIdea, 'Pasta');
    },
  );

  testWidgets(
    'local recognition runs on demand; uncertain and existing days are not preselected',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var recognitions = 0;
      final photo = base64Decode(
        'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAIAAACQd1PeAAAADElEQVR4nGP4//8/AAX+Av4N70a4AAAAAElFTkSuQmCC',
      );
      await tester.pumpWidget(
        MaterialApp(
          home: PhotoWeekPlanScreen(
            mealPlan: original.mealPlan,
            recipes: original.recipes,
            initialPhoto: photo,
            recognize: (_) async {
              recognitions++;
              return const PhotoWeekDraft(
                days: [
                  PhotoMealDraft(weekday: WeekdayDe.montag, meal: 'Risotto'),
                  PhotoMealDraft(
                    weekday: WeekdayDe.mittwoch,
                    meal: 'Curry',
                    uncertain: true,
                  ),
                  PhotoMealDraft(weekday: WeekdayDe.donnerstag, meal: 'Salat'),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(recognitions, 0);
      await tester.ensureVisible(find.text('Handschrift auslesen'));
      await tester.tap(find.text('Handschrift auslesen'));
      await tester.pumpAndSettle();
      expect(recognitions, 1);
      final tiles = tester
          .widgetList<CheckboxListTile>(find.byType(CheckboxListTile))
          .toList();
      expect(tiles[0].value, false);
      expect(tiles[2].value, false);
      expect(tiles[3].value, true);
    },
  );

  testWidgets(
    'replacing an existing day requires confirmation and returns only selected days',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<WeekdayDe, String>? result;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await Navigator.push<Map<WeekdayDe, String>>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PhotoWeekPlanScreen(
                        mealPlan: original.mealPlan,
                        recipes: original.recipes,
                      ),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Risotto');
      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();
      final save = find.text('1 Tage in den Wochenplan übernehmen');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Geplante Tage ersetzen?'), findsOneWidget);
      expect(result, isNull);
      await tester.tap(find.text('Abbrechen').last);
      await tester.pumpAndSettle();
      expect(result, isNull);
      await tester.tap(save);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Diese Tage ersetzen'));
      await tester.pumpAndSettle();
      expect(result, {WeekdayDe.montag: 'Risotto'});
      expect(original.mealPlan.entryFor(WeekdayDe.montag)?.dishIdea, 'Pasta');
    },
  );
}

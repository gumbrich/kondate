import 'package:core/core.dart';
import 'package:test/test.dart';

void main() {
  test('meal plan upsert replaces matching weekday', () {
    const first = MealPlanEntry(
      weekday: WeekdayDe.montag,
      dishIdea: 'Curry',
      recipeId: 'r1',
    );

    const second = MealPlanEntry(
      weekday: WeekdayDe.montag,
      dishIdea: 'Dal',
      recipeId: 'r2',
    );

    final plan = MealPlanWeek(entries: const [first]);
    final updated = plan.upsert(second);

    expect(updated.entries.length, 1);
    expect(updated.entries.first.dishIdea, 'Dal');
    expect(updated.entries.first.recipeId, 'r2');
  });
}

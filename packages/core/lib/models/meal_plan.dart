enum WeekdayDe {
  montag,
  dienstag,
  mittwoch,
  donnerstag,
  freitag,
  samstag,
  sonntag,
}

class MealPlanEntry {
  final WeekdayDe weekday;
  final String? dishIdea;
  final String? recipeId;

  const MealPlanEntry({
    required this.weekday,
    this.dishIdea,
    this.recipeId,
  });

  MealPlanEntry copyWith({
    WeekdayDe? weekday,
    String? dishIdea,
    String? recipeId,
  }) {
    return MealPlanEntry(
      weekday: weekday ?? this.weekday,
      dishIdea: dishIdea ?? this.dishIdea,
      recipeId: recipeId ?? this.recipeId,
    );
  }
}

class MealPlanWeek {
  final List<MealPlanEntry> entries;

  const MealPlanWeek({required this.entries});

  MealPlanEntry? entryFor(WeekdayDe weekday) {
    for (final entry in entries) {
      if (entry.weekday == weekday) return entry;
    }
    return null;
  }

  MealPlanWeek upsert(MealPlanEntry newEntry) {
    final updated = <MealPlanEntry>[];
    var replaced = false;

    for (final entry in entries) {
      if (entry.weekday == newEntry.weekday) {
        updated.add(newEntry);
        replaced = true;
      } else {
        updated.add(entry);
      }
    }

    if (!replaced) {
      updated.add(newEntry);
    }

    return MealPlanWeek(entries: updated);
  }
}

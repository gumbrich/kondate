import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/household_api_models.dart';

void main() {
  test('household sync snapshot serializes and deserializes', () {
    const HouseholdSyncSnapshotDto snapshot = HouseholdSyncSnapshotDto(
      household: HouseholdDto(
        householdId: 'h1',
        name: 'Knoerzer Family',
        members: <HouseholdMemberDto>[
          HouseholdMemberDto(userId: 'u1', displayName: 'Johannes'),
          HouseholdMemberDto(userId: 'u2', displayName: 'Alma'),
        ],
      ),
      mealPlanEntries: <MealPlanEntryDto>[
        MealPlanEntryDto(
          weekday: 'montag',
          dishIdea: 'Lasagne',
          recipeId: 'r1',
        ),
      ],
      trustedSites: TrustedSitesDto(
        sites: <String>['chefkoch.de', 'springlane.de'],
        topN: 3,
      ),
      shoppingItemStates: <ShoppingItemStateDto>[
        ShoppingItemStateDto(itemKey: 'gemuese__tomate', checked: true),
      ],
    );

    final Map<String, dynamic> json = snapshot.toJson();
    final HouseholdSyncSnapshotDto restored =
        HouseholdSyncSnapshotDto.fromJson(json);

    expect(restored.household.householdId, 'h1');
    expect(restored.household.members.length, 2);
    expect(restored.mealPlanEntries.first.dishIdea, 'Lasagne');
    expect(restored.trustedSites.sites.first, 'chefkoch.de');
    expect(restored.shoppingItemStates.first.checked, true);
  });
}

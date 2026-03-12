import 'household_api_models.dart';

abstract class HouseholdSyncProvider {
  Future<HouseholdSyncSnapshotDto> fetchSnapshot({
    required String householdId,
  });

  Future<void> pushSnapshot({
    required HouseholdSyncSnapshotDto snapshot,
  });
}

class MockHouseholdSyncProvider implements HouseholdSyncProvider {
  const MockHouseholdSyncProvider();

  @override
  Future<HouseholdSyncSnapshotDto> fetchSnapshot({
    required String householdId,
  }) async {
    return HouseholdSyncSnapshotDto(
      household: HouseholdDto(
        householdId: householdId,
        name: 'Demo Household',
        members: const <HouseholdMemberDto>[
          HouseholdMemberDto(userId: 'u1', displayName: 'Johannes'),
          HouseholdMemberDto(userId: 'u2', displayName: 'Alma'),
        ],
      ),
      mealPlanEntries: const <MealPlanEntryDto>[
        MealPlanEntryDto(
          weekday: 'montag',
          dishIdea: 'Lasagne',
          recipeId: null,
        ),
      ],
      trustedSites: const TrustedSitesDto(
        sites: <String>[
          'chefkoch.de',
          'eatsmarter.de',
          'springlane.de',
        ],
        topN: 3,
      ),
      shoppingItemStates: const <ShoppingItemStateDto>[
        ShoppingItemStateDto(
          itemKey: 'gemuese__tomate',
          checked: true,
        ),
      ],
    );
  }

  @override
  Future<void> pushSnapshot({
    required HouseholdSyncSnapshotDto snapshot,
  }) async {}
}

class HttpHouseholdSyncProvider implements HouseholdSyncProvider {
  final Uri baseUri;

  const HttpHouseholdSyncProvider({
    required this.baseUri,
  });

  @override
  Future<HouseholdSyncSnapshotDto> fetchSnapshot({
    required String householdId,
  }) async {
    throw UnimplementedError(
      'Backend sync not wired yet. Later this will GET '
      '$baseUri/households/$householdId/snapshot.',
    );
  }

  @override
  Future<void> pushSnapshot({
    required HouseholdSyncSnapshotDto snapshot,
  }) async {
    throw UnimplementedError(
      'Backend sync not wired yet. Later this will PUT '
      '$baseUri/households/${snapshot.household.householdId}/snapshot.',
    );
  }
}

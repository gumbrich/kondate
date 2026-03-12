import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/household_sync_provider.dart';

void main() {
  test('mock household sync provider returns demo snapshot', () async {
    const MockHouseholdSyncProvider provider = MockHouseholdSyncProvider();

    final snapshot = await provider.fetchSnapshot(householdId: 'demo-household');

    expect(snapshot.household.householdId, 'demo-household');
    expect(snapshot.household.members.length, 2);
    expect(snapshot.trustedSites.topN, 3);
    expect(snapshot.mealPlanEntries.first.weekday, 'montag');
  });

  test('mock household sync provider accepts push', () async {
    const MockHouseholdSyncProvider provider = MockHouseholdSyncProvider();

    final snapshot = await provider.fetchSnapshot(householdId: 'demo-household');

    await provider.pushSnapshot(snapshot: snapshot);
  });
}

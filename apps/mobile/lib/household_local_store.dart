import 'package:shared_preferences/shared_preferences.dart';

class HouseholdLocalStore {
  static const String _householdIdKey = 'kondate_household_id';
  static const String _joinCodeKey = 'kondate_household_join_code';

  Future<void> save({
    required String householdId,
    required String joinCode,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_householdIdKey, householdId);
    await prefs.setString(_joinCodeKey, joinCode);
  }

  Future<void> clear() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_householdIdKey);
    await prefs.remove(_joinCodeKey);
  }

  Future<StoredHouseholdInfo?> load() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? householdId = prefs.getString(_householdIdKey);
    final String? joinCode = prefs.getString(_joinCodeKey);

    if (householdId == null || householdId.isEmpty) {
      return null;
    }

    return StoredHouseholdInfo(
      householdId: householdId,
      joinCode: joinCode,
    );
  }
}

class StoredHouseholdInfo {
  final String householdId;
  final String? joinCode;

  const StoredHouseholdInfo({
    required this.householdId,
    required this.joinCode,
  });
}

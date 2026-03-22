import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'coop_user_preferences.dart';

class CoopUserPreferencesStore {
  static const String _storageKey = 'coop_user_preference_overrides_v1';

  Future<Map<String, CoopUserPreferenceOverride>> loadOverrides() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? raw = prefs.getString(_storageKey);

    if (raw == null || raw.trim().isEmpty) {
      return <String, CoopUserPreferenceOverride>{};
    }

    final Object? decoded = jsonDecode(raw);
    if (decoded is! List<dynamic>) {
      return <String, CoopUserPreferenceOverride>{};
    }

    final Map<String, CoopUserPreferenceOverride> result =
        <String, CoopUserPreferenceOverride>{};

    for (final dynamic entry in decoded) {
      if (entry is Map<String, dynamic>) {
        final CoopUserPreferenceOverride override =
            CoopUserPreferenceOverride.fromJson(entry);
        if (override.canonicalKey.isNotEmpty) {
          result[override.canonicalKey] = override;
        }
      } else if (entry is Map) {
        final Map<String, dynamic> converted = <String, dynamic>{};
        entry.forEach((dynamic key, dynamic value) {
          converted[key.toString()] = value;
        });
        final CoopUserPreferenceOverride override =
            CoopUserPreferenceOverride.fromJson(converted);
        if (override.canonicalKey.isNotEmpty) {
          result[override.canonicalKey] = override;
        }
      }
    }

    return result;
  }

  Future<void> saveOverrides(
    Map<String, CoopUserPreferenceOverride> overrides,
  ) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final List<Map<String, dynamic>> payload = overrides.values
        .map((CoopUserPreferenceOverride item) => item.toJson())
        .toList();

    await prefs.setString(_storageKey, jsonEncode(payload));
  }

  Future<void> saveOverride(CoopUserPreferenceOverride override) async {
    final Map<String, CoopUserPreferenceOverride> current =
        await loadOverrides();
    current[override.canonicalKey] = override;
    await saveOverrides(current);
  }

  Future<void> removeOverride(String canonicalKey) async {
    final Map<String, CoopUserPreferenceOverride> current =
        await loadOverrides();
    current.remove(canonicalKey);
    await saveOverrides(current);
  }
}

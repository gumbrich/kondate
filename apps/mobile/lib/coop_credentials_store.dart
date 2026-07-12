import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CoopCredentials {
  final String email;
  final String password;

  const CoopCredentials({required this.email, required this.password});

  bool get isComplete => email.trim().isNotEmpty && password.isNotEmpty;
}

class CoopCredentialsStore {
  CoopCredentialsStore({
    FlutterSecureStorage? storage,
    Future<SharedPreferences> Function()? macOsDebugPreferencesLoader,
    bool? useMacOsDebugFallback,
  }) : _storage = storage ?? const FlutterSecureStorage(),
       _macOsDebugPreferencesLoader =
           macOsDebugPreferencesLoader ?? SharedPreferences.getInstance,
       _useMacOsDebugFallback = useMacOsDebugFallback;

  final FlutterSecureStorage _storage;
  final Future<SharedPreferences> Function() _macOsDebugPreferencesLoader;
  final bool? _useMacOsDebugFallback;

  static const String _emailKey = 'coop_email_v1';
  static const String _passwordKey = 'coop_password_v1';
  static const String _macOsDebugEmailKey = 'coop_macos_debug_email_v1';
  static const String _macOsDebugPasswordKey = 'coop_macos_debug_password_v1';

  bool get _usesMacOsDebugFallback =>
      _useMacOsDebugFallback ??
      (kDebugMode && defaultTargetPlatform == TargetPlatform.macOS);

  Future<CoopCredentials> load() async {
    if (_usesMacOsDebugFallback) {
      final SharedPreferences prefs = await _macOsDebugPreferencesLoader();
      return CoopCredentials(
        email: prefs.getString(_macOsDebugEmailKey) ?? '',
        password: prefs.getString(_macOsDebugPasswordKey) ?? '',
      );
    }

    final String email = await _storage.read(key: _emailKey) ?? '';
    final String password = await _storage.read(key: _passwordKey) ?? '';

    return CoopCredentials(email: email, password: password);
  }

  Future<void> save({required String email, required String password}) async {
    if (_usesMacOsDebugFallback) {
      final SharedPreferences prefs = await _macOsDebugPreferencesLoader();
      await prefs.setString(_macOsDebugEmailKey, email.trim());
      await prefs.setString(_macOsDebugPasswordKey, password);
      return;
    }

    await _storage.write(key: _emailKey, value: email.trim());
    await _storage.write(key: _passwordKey, value: password);
  }

  Future<void> clear() async {
    if (_usesMacOsDebugFallback) {
      final SharedPreferences prefs = await _macOsDebugPreferencesLoader();
      await prefs.remove(_macOsDebugEmailKey);
      await prefs.remove(_macOsDebugPasswordKey);
      return;
    }

    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
  }
}

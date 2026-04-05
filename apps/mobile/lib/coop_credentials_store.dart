import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class CoopCredentials {
  final String email;
  final String password;

  const CoopCredentials({
    required this.email,
    required this.password,
  });

  bool get isComplete => email.trim().isNotEmpty && password.isNotEmpty;
}

class CoopCredentialsStore {
  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  static const String _emailKey = 'coop_email_v1';
  static const String _passwordKey = 'coop_password_v1';

  Future<CoopCredentials> load() async {
    final String email = await _storage.read(key: _emailKey) ?? '';
    final String password = await _storage.read(key: _passwordKey) ?? '';

    return CoopCredentials(
      email: email,
      password: password,
    );
  }

  Future<void> save({
    required String email,
    required String password,
  }) async {
    await _storage.write(key: _emailKey, value: email.trim());
    await _storage.write(key: _passwordKey, value: password);
  }

  Future<void> clear() async {
    await _storage.delete(key: _emailKey);
    await _storage.delete(key: _passwordKey);
  }
}

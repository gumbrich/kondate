import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/coop_credentials_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('macOS debug fallback saves, loads, and clears credentials', () async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    final CoopCredentialsStore store = CoopCredentialsStore(
      useMacOsDebugFallback: true,
    );

    await store.save(email: '  alice@example.com ', password: 'password');

    expect(
      await store.load(),
      isA<CoopCredentials>()
          .having(
            (CoopCredentials credentials) => credentials.email,
            'email',
            'alice@example.com',
          )
          .having(
            (CoopCredentials credentials) => credentials.password,
            'password',
            'password',
          ),
    );

    await store.clear();

    final CoopCredentials credentials = await store.load();
    expect(credentials.email, isEmpty);
    expect(credentials.password, isEmpty);
  });
}

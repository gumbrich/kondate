import 'dart:convert';
import 'dart:io';

class HouseholdInfo {
  final String householdId;
  final String joinCode;

  const HouseholdInfo({
    required this.householdId,
    required this.joinCode,
  });
}

class HouseholdApi {
  static final Uri _baseUri = Uri.parse('http://127.0.0.1:8000');

  Future<HouseholdInfo> createHousehold() async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request =
          await client.postUrl(_baseUri.resolve('/households'));
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Create household failed: $body');
      }

      final Map<String, dynamic> json =
          jsonDecode(body) as Map<String, dynamic>;

      return HouseholdInfo(
        householdId: json['householdId'] as String,
        joinCode: json['joinCode'] as String,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<HouseholdInfo> joinHousehold(String joinCode) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request =
          await client.postUrl(_baseUri.resolve('/households/join'));
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(<String, dynamic>{'joinCode': joinCode}));
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Join household failed: $body');
      }

      final Map<String, dynamic> json =
          jsonDecode(body) as Map<String, dynamic>;

      return HouseholdInfo(
        householdId: json['householdId'] as String,
        joinCode: json['joinCode'] as String,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<Map<String, dynamic>> loadState(String householdId) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.getUrl(
        _baseUri.resolve('/households/$householdId/state'),
      );
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Load household state failed: $body');
      }

      final Map<String, dynamic> json =
          jsonDecode(body) as Map<String, dynamic>;
      return json['state'] as Map<String, dynamic>;
    } finally {
      client.close(force: true);
    }
  }

  Future<void> saveState(String householdId, Map<String, dynamic> state) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.putUrl(
        _baseUri.resolve('/households/$householdId/state'),
      );
      request.headers.contentType = ContentType.json;
      request.write(jsonEncode(<String, dynamic>{'state': state}));
      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Save household state failed: $body');
      }
    } finally {
      client.close(force: true);
    }
  }
}

import 'dart:convert';
import 'dart:io';

import 'backend_config.dart';

class HouseholdInfo {
  final String householdId;
  final String joinCode;

  const HouseholdInfo({
    required this.householdId,
    required this.joinCode,
  });
}

class HouseholdStatePayload {
  final String updatedAt;
  final Map<String, dynamic> state;

  const HouseholdStatePayload({
    required this.updatedAt,
    required this.state,
  });
}

class HouseholdConflictException implements Exception {
  final String message;

  const HouseholdConflictException(this.message);

  @override
  String toString() => message;
}

class HouseholdApi {
  static final Uri _baseUri = Uri.parse(backendBaseUrl);

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

  Future<HouseholdStatePayload> loadState(String householdId) async {
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

      return HouseholdStatePayload(
        updatedAt: json['updatedAt'] as String,
        state: json['state'] as Map<String, dynamic>,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<String?> saveState(
    String householdId,
    Map<String, dynamic> state, {
    required String? lastSeenUpdatedAt,
  }) async {
    final HttpClient client = HttpClient();
    try {
      final HttpClientRequest request = await client.putUrl(
        _baseUri.resolve('/households/$householdId/state'),
      );
      request.headers.contentType = ContentType.json;
      request.write(
        jsonEncode(<String, dynamic>{
          'state': state,
          'lastSeenUpdatedAt': lastSeenUpdatedAt,
        }),
      );

      final HttpClientResponse response = await request.close();
      final String body = await response.transform(utf8.decoder).join();

      if (response.statusCode == 409) {
        throw HouseholdConflictException(body);
      }

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Save household state failed: $body');
      }

      final Map<String, dynamic> json =
          jsonDecode(body) as Map<String, dynamic>;
      return json['updatedAt'] as String?;
    } finally {
      client.close(force: true);
    }
  }
}

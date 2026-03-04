import 'dart:io';
import 'package:http/http.dart' as http;

class PageFetcher {
  Future<String> fetchHtml(Uri url) async {
<<<<<<< Updated upstream
    final res = await http.get(
      url,
      headers: const {
        'User-Agent': 'kondate/0.1 (household MVP)',
        'Accept': 'text/html,application/xhtml+xml',
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode} for $url');
=======
    try {
      final res = await http.get(
        url,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'de-DE,de;q=0.9,en;q=0.8',
          // IMPORTANT: avoid brotli surprises; keep it simple
          'Accept-Encoding': 'gzip, deflate',
        },
      ).timeout(const Duration(seconds: 20));

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode} for $url');
      }
      return res.body;
    } on SocketException catch (e) {
      throw Exception('SocketException fetching $url: ${e.message}');
    } on http.ClientException catch (e) {
      throw Exception('ClientException fetching $url: ${e.message}');
    } on TimeoutException {
      throw Exception('Timeout fetching $url');
>>>>>>> Stashed changes
    }
  }
}
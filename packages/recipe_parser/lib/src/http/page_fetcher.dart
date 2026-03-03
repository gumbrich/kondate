import 'package:http/http.dart' as http;

class PageFetcher {
  Future<String> fetchHtml(Uri url) async {
      final res = await http.get(
        url,
        headers: const {
          'User-Agent':
              'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36',
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Accept-Language': 'de-DE,de;q=0.9,en;q=0.8',
          'Cache-Control': 'no-cache',
        },
      );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode} for $url');
    }
    return res.body;
  }
}

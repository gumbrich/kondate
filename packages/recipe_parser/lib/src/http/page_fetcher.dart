import 'package:http/http.dart' as http;

class PageFetcher {
  Future<String> fetchHtml(Uri url) async {
    final res = await http.get(
      url,
      headers: const {
        'User-Agent': 'kondate/0.1 (household MVP)',
        'Accept': 'text/html,application/xhtml+xml',
      },
    );
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception('HTTP ${res.statusCode} for $url');
    }
    return res.body;
  }
}

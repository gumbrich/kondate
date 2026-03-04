import 'dart:async';
import 'dart:convert';
import 'dart:io';

class PageFetcher {
  final HttpClient _client;

  PageFetcher({HttpClient? client}) : _client = client ?? HttpClient() {
    _client.autoUncompress = true;
    _client.userAgent =
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0 Safari/537.36';
  }

  Future<String> fetchHtml(Uri url) async {
    try {
      final req = await _client.getUrl(url);

      req.headers.set(
        'Accept',
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      );
      req.headers.set('Accept-Language', 'de-DE,de;q=0.9,en;q=0.8');
      req.headers.set(HttpHeaders.acceptEncodingHeader, 'gzip, deflate');

      final res = await req.close().timeout(const Duration(seconds: 20));

      if (res.isRedirect &&
          res.headers.value(HttpHeaders.locationHeader) != null) {
        final loc = res.headers.value(HttpHeaders.locationHeader)!;
        return fetchHtml(url.resolve(loc));
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode} for $url');
      }

      final bytes = await res.fold<List<int>>(<int>[], (a, b) => a..addAll(b));

      try {
        return utf8.decode(bytes);
      } catch (_) {
        return latin1.decode(bytes);
      }
    } on TimeoutException {
      throw Exception('Timeout fetching $url');
    } on SocketException catch (e) {
      throw Exception('SocketException fetching $url: ${e.message}');
    } on HandshakeException catch (e) {
      throw Exception('HandshakeException fetching $url: $e');
    }
  }
}

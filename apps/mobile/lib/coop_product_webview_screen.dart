import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CoopProductWebViewScreen extends StatefulWidget {
  final String title;
  final String productUrl;

  const CoopProductWebViewScreen({
    super.key,
    required this.title,
    required this.productUrl,
  });

  @override
  State<CoopProductWebViewScreen> createState() =>
      _CoopProductWebViewScreenState();
}

class _CoopProductWebViewScreenState extends State<CoopProductWebViewScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _lastJsResult;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
            });
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() {
              _loading = false;
            });
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.productUrl));
  }

  Future<void> _reload() async {
    await _controller.reload();
  }

  Future<void> _inspectPage() async {
    const String script = r'''
(() => {
  return JSON.stringify({
    href: window.location.href,
    title: document.title
  });
})();
''';

    try {
      final Object result =
          await _controller.runJavaScriptReturningResult(script);

      if (!mounted) return;
      setState(() {
        _lastJsResult = result.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seite geprüft: $_lastJsResult')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastJsResult = 'inspect-error: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Seitenprüfung fehlgeschlagen: $e')),
      );
    }
  }

  Future<void> _inspectCandidates() async {
    const String script = r'''
(() => {
  function normalize(text) {
    return (text || '')
      .replace(/\s+/g, ' ')
      .trim()
      .toLowerCase();
  }

  function visible(el) {
    if (!el) return false;
    const style = window.getComputedStyle(el);
    if (!style) return true;
    if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') {
      return false;
    }
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  }

  function attrs(el) {
    return normalize([
      el.innerText || '',
      el.textContent || '',
      el.value || '',
      el.getAttribute('aria-label') || '',
      el.getAttribute('title') || '',
      el.id || '',
      el.className || '',
      el.getAttribute('data-testid') || '',
      el.getAttribute('data-testauto') || '',
      el.getAttribute('name') || ''
    ].join(' '));
  }

  function short(s) {
    return (s || '').replace(/\s+/g, ' ').trim().slice(0, 220);
  }

  const nodes = Array.from(
    document.querySelectorAll('button, a, input[type="button"], input[type="submit"]')
  );

  const results = [];

  for (const el of nodes) {
    const text = attrs(el);
    if (!text) continue;
    if (!visible(el)) continue;

    const interesting =
      text.includes('warenkorb') ||
      text.includes('korb') ||
      text.includes('add') ||
      text.includes('basket') ||
      text.includes('cart') ||
      text.includes('kasse') ||
      text.includes('hinzu') ||
      text.includes('kaufen') ||
      text.includes('buy');

    if (!interesting) continue;

    results.push({
      tag: el.tagName,
      text: short(text),
      id: short(el.id || ''),
      className: short(el.className || ''),
      dataTestauto: short(el.getAttribute('data-testauto') || ''),
      dataTestid: short(el.getAttribute('data-testid') || ''),
      aria: short(el.getAttribute('aria-label') || ''),
      title: short(el.getAttribute('title') || '')
    });
  }

  return JSON.stringify(results.slice(0, 25), null, 2);
})();
''';

    try {
      final Object result =
          await _controller.runJavaScriptReturningResult(script);

      if (!mounted) return;

      setState(() {
        _lastJsResult = result.toString();
      });

      await showDialog<void>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Kandidaten'),
            content: SingleChildScrollView(
              child: SelectableText(
                result.toString(),
                style: const TextStyle(fontSize: 12),
              ),
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Schließen'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastJsResult = 'candidate-error: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kandidaten-Inspektion fehlgeschlagen: $e')),
      );
    }
  }

  Future<void> _runAddToCartJs() async {
    const String script = r'''
(() => {
  function normalize(text) {
    return (text || '')
      .replace(/\s+/g, ' ')
      .trim()
      .toLowerCase();
  }

  function visible(el) {
    if (!el) return false;
    const style = window.getComputedStyle(el);
    if (!style) return true;
    if (style.display === 'none' || style.visibility === 'hidden' || style.opacity === '0') {
      return false;
    }
    const rect = el.getBoundingClientRect();
    return rect.width > 0 && rect.height > 0;
  }

  function attrs(el) {
    return normalize([
      el.innerText || '',
      el.textContent || '',
      el.value || '',
      el.getAttribute('aria-label') || '',
      el.getAttribute('title') || '',
      el.id || '',
      el.className || '',
      el.getAttribute('data-testid') || '',
      el.getAttribute('data-testauto') || '',
      el.getAttribute('name') || ''
    ].join(' '));
  }

  const currentUrl = normalize(window.location.href);
  if (currentUrl.includes('/cart') || currentUrl.includes('/basket')) {
    return 'wrong-page:cart';
  }

  const candidates = Array.from(
    document.querySelectorAll('button, a, input[type="button"], input[type="submit"]')
  );

  const strongPositivePhrases = [
    'in den warenkorb',
    'zum warenkorb hinzufügen',
    'zum warenkorb hinzufugen',
    'add to cart'
  ];

  const weakPositivePhrases = [
    'hinzufügen',
    'hinzufugen',
    'add'
  ];

  const negativePhrases = [
    'warenkorb wert',
    'öffnet mini-warenkorb',
    'oeffnet mini-warenkorb',
    'mini-warenkorb',
    'mein warenkorb',
    'zur kasse',
    'checkout',
    'basket value'
  ];

  let best = null;
  let bestScore = -9999;

  for (const el of candidates) {
    if (!visible(el)) continue;

    const text = attrs(el);
    if (!text) continue;

    let score = 0;

    for (const phrase of strongPositivePhrases) {
      if (text.includes(phrase)) score += 100;
    }

    for (const phrase of weakPositivePhrases) {
      if (text.includes(phrase)) score += 20;
    }

    for (const phrase of negativePhrases) {
      if (text.includes(phrase)) score -= 200;
    }

    if (text === 'warenkorb' || text === 'basket' || text === 'cart') {
      score -= 500;
    }

    if (
      text.includes('addtocart') ||
      text.includes('add-to-cart') ||
      text.includes('basket/detail/add')
    ) {
      score += 120;
    }

    if (score > bestScore) {
      bestScore = score;
      best = { el, text, score };
    }
  }

  if (!best || bestScore < 50) {
    return 'no-add-to-cart-match';
  }

  best.el.click();
  return `clicked:${best.text}::score=${best.score}`;
})();
''';

    try {
      final Object result =
          await _controller.runJavaScriptReturningResult(script);

      if (!mounted) return;
      setState(() {
        _lastJsResult = result.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('JS-Ergebnis: $_lastJsResult')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastJsResult = 'error: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('JS-Fehler: $e')),
      );
    }
  }

  Future<void> _inspectTitle() async {
    try {
      final Object result = await _controller.runJavaScriptReturningResult(
        'document.title',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Titel: $result')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Konnte Titel nicht lesen: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: <Widget>[
          IconButton(
            tooltip: 'Seite prüfen',
            onPressed: _inspectPage,
            icon: const Icon(Icons.rule_folder_outlined),
          ),
          IconButton(
            tooltip: 'Kandidaten prüfen',
            onPressed: _inspectCandidates,
            icon: const Icon(Icons.list_alt),
          ),
          IconButton(
            tooltip: 'Titel testen',
            onPressed: _inspectTitle,
            icon: const Icon(Icons.info_outline),
          ),
          IconButton(
            tooltip: 'Neu laden',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'JS Add-to-cart testen',
            onPressed: _runAddToCartJs,
            icon: const Icon(Icons.play_arrow),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          WebViewWidget(controller: _controller),
          if (_loading) const LinearProgressIndicator(),
          if (_lastJsResult != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Card(
                color: Colors.black87,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'Letztes JS-Ergebnis: $_lastJsResult',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

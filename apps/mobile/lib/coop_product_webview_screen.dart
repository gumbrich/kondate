import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'coop_basket_service.dart';
import 'coop_basket_webview.dart';

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
  late final CoopBasketWebView _basketPage;
  bool _loading = true;
  bool _runningAction = false;
  String? _lastJsResult;

  @override
  void initState() {
    super.initState();

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame == true) {
              _basketPage.onPageError();
              if (mounted) setState(() => _loading = false);
            }
          },
          onPageStarted: (_) {
            if (!mounted) return;
            setState(() {
              _loading = true;
            });
          },
          onPageFinished: (_) {
            _basketPage.onPageFinished();
            if (!mounted) return;
            setState(() {
              _loading = false;
            });
          },
        ),
      );
    _basketPage = CoopBasketWebView(_controller);
    _controller.loadRequest(Uri.parse(widget.productUrl));
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
      final Object result = await _controller.runJavaScriptReturningResult(
        script,
      );

      if (!mounted) return;
      setState(() {
        _lastJsResult = result.toString();
      });

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Seite geprüft: $_lastJsResult')));
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
      text.includes('buy') ||
      text.includes('productbasketplus') ||
      text.includes('productbasketminus');

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

  return JSON.stringify(results.slice(0, 40), null, 2);
})();
''';

    try {
      final Object result = await _controller.runJavaScriptReturningResult(
        script,
      );

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
    if (_runningAction || _loading) return;
    final int? target = await showDialog<int>(
      context: context,
      builder: (BuildContext context) {
        int quantity = 1;
        return StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Zielmenge im Warenkorb'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Text(
                  'Gesamtzahl der Packungen, inklusive bereits vorhandener.',
                ),
                DropdownButton<int>(
                  value: quantity,
                  items: List<DropdownMenuItem<int>>.generate(
                    20,
                    (i) => DropdownMenuItem<int>(
                      value: i + 1,
                      child: Text('${i + 1} Packung(en)'),
                    ),
                  ),
                  onChanged: (value) => update(() => quantity = value ?? 1),
                ),
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, quantity),
                child: const Text('Prüfen / ergänzen'),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || target == null) return;
    setState(() => _runningAction = true);
    try {
      final CoopBasketResult result = await CoopBasketService(page: _basketPage)
          .ensureQuantity(
            productUrl: widget.productUrl,
            targetQuantity: target,
            isCancelled: () => !mounted,
          );
      if (!mounted) return;
      setState(() => _lastJsResult = result.message);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(result.message)));
    } finally {
      if (mounted) setState(() => _runningAction = false);
    }
  }

  Future<void> _inspectTitle() async {
    try {
      final Object result = await _controller.runJavaScriptReturningResult(
        'document.title',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Titel: $result')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Konnte Titel nicht lesen: $e')));
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
            onPressed: _runningAction || _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Warenkorb-Zielmenge prüfen',
            onPressed: _runningAction || _loading ? null : _runAddToCartJs,
            icon: const Icon(Icons.play_arrow),
          ),
        ],
      ),
      body: Stack(
        children: <Widget>[
          AbsorbPointer(
            absorbing: _runningAction,
            child: WebViewWidget(controller: _controller),
          ),
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
                  child: SelectableText(
                    'Warenkorb-Prüfung:\n$_lastJsResult',
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

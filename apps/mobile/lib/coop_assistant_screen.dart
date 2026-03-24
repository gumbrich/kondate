import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'coop_saved_product.dart';

class CoopAssistantScreen extends StatefulWidget {
  final List<CoopSavedProduct> products;

  const CoopAssistantScreen({
    super.key,
    required this.products,
  });

  @override
  State<CoopAssistantScreen> createState() => _CoopAssistantScreenState();
}

class _CoopAssistantScreenState extends State<CoopAssistantScreen> {
  late final WebViewController _controller;

  int _index = 0;
  bool _loading = true;
  bool _running = false;
  bool _autoAdvance = true;
  bool _fullAutoRun = false;
  String? _lastResult;

  CoopSavedProduct get _current => widget.products[_index];

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
      );

    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    await _controller.loadRequest(Uri.parse(_current.productUrl));
  }

  Future<void> _reload() async {
    await _controller.reload();
  }

  void _next() {
    if (_index >= widget.products.length - 1) return;

    setState(() {
      _index++;
      _lastResult = null;
    });
    _loadCurrent();
  }

  void _prev() {
    if (_index <= 0) return;

    setState(() {
      _index--;
      _lastResult = null;
      _fullAutoRun = false;
    });
    _loadCurrent();
  }

  Future<void> _advanceIfPossible() async {
    if (_index < widget.products.length - 1) {
      setState(() {
        _index++;
        _lastResult = null;
      });
      await _loadCurrent();
      return;
    }

    if (!mounted) return;
    setState(() {
      _fullAutoRun = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Auto-Run abgeschlossen'),
      ),
    );
  }

  Future<void> _waitForPageToSettle() async {
    await Future<void>.delayed(const Duration(milliseconds: 1800));
  }

  Future<bool> _runAddInternal() async {
    const String stateScript = r'''
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

  const plus = document.querySelector('[data-testauto^="productbasketplus"]');
  const minus = document.querySelector('[data-testauto^="productbasketminus"]');
  const basket = document.querySelector('[data-testauto="basket"]');

  const basketText = basket
    ? normalize(
        (basket.innerText || '') + ' ' +
        (basket.getAttribute('aria-label') || '') + ' ' +
        (basket.getAttribute('title') || '')
      )
    : '';

  return JSON.stringify({
    href: window.location.href,
    hasPlus: !!(plus && visible(plus)),
    hasMinus: !!(minus && visible(minus)),
    basketText: basketText
  });
})();
''';

    const String clickScript = r'''
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

  const plusButton = document.querySelector('[data-testauto^="productbasketplus"]');
  if (plusButton && visible(plusButton)) {
    plusButton.click();
    return 'clicked:productbasketplus';
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
    'basket value',
    'productbasketminus',
    'productbasketplus'
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

    final Object before =
        await _controller.runJavaScriptReturningResult(stateScript);

    final Object clickResult =
        await _controller.runJavaScriptReturningResult(clickScript);

    await Future<void>.delayed(const Duration(milliseconds: 1400));

    final Object after =
        await _controller.runJavaScriptReturningResult(stateScript);

    final String clickText = clickResult.toString();
    final String result = 'before=$before\nclick=$clickText\nafter=$after';

    if (!mounted) return false;
    setState(() {
      _lastResult = result;
    });

    return clickText.startsWith('clicked:');
  }

  Future<void> _runAdd() async {
    if (_running) return;

    setState(() {
      _running = true;
    });

    try {
      final bool success = await _runAddInternal();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? 'Produktaktion erfolgreich ausgelöst'
                : 'Kein passender Add-to-cart-Kandidat gefunden',
          ),
          duration: const Duration(seconds: 2),
        ),
      );

      if (success && _autoAdvance) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
        if (!mounted) return;
        await _advanceIfPossible();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastResult = 'error: $e';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }

  Future<void> _runAll() async {
    if (_running) return;

    setState(() {
      _running = true;
      _fullAutoRun = true;
    });

    try {
      while (mounted && _fullAutoRun) {
        await _waitForPageToSettle();
        final bool success = await _runAddInternal();

        if (!mounted) return;

        if (!success) {
          setState(() {
            _fullAutoRun = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Auto-Run gestoppt: Kein passender Add-to-cart-Kandidat gefunden',
              ),
              duration: Duration(seconds: 3),
            ),
          );
          break;
        }

        if (_index >= widget.products.length - 1) {
          setState(() {
            _fullAutoRun = false;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Auto-Run abgeschlossen'),
              duration: Duration(seconds: 2),
            ),
          );
          break;
        }

        await Future<void>.delayed(const Duration(milliseconds: 800));
        await _advanceIfPossible();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastResult = 'error: $e';
        _fullAutoRun = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Auto-Run Fehler: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }

  void _stopAutoRun() {
    setState(() {
      _fullAutoRun = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool hasPrev = _index > 0;
    final bool hasNext = _index < widget.products.length - 1;

    return Scaffold(
      appBar: AppBar(
        title: Text('Coop-Assistent ${_index + 1}/${widget.products.length}'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Neu laden',
            onPressed: _running ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Card(
            margin: const EdgeInsets.all(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    _current.productLabel,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _current.canonicalKey,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _current.productUrl,
                    style: const TextStyle(fontSize: 12),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Automatisch zum nächsten Produkt'),
                    value: _autoAdvance,
                    onChanged: _running
                        ? null
                        : (bool value) {
                            setState(() {
                              _autoAdvance = value;
                            });
                          },
                  ),
                ],
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
          if (_lastResult != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Card(
                color: Colors.black87,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    _lastResult!,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton.icon(
                  onPressed: (_running || !hasPrev) ? null : _prev,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Zurück'),
                ),
                FilledButton.icon(
                  onPressed: _running ? null : _runAdd,
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(_running ? 'Läuft...' : 'Automatisch hinzufügen'),
                ),
                FilledButton.tonalIcon(
                  onPressed: (_running || !hasNext) ? null : _next,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Weiter'),
                ),
                if (!_fullAutoRun)
                  ElevatedButton.icon(
                    onPressed: _running ? null : _runAll,
                    icon: const Icon(Icons.play_circle_outline),
                    label: const Text('Auto-Run starten'),
                  ),
                if (_fullAutoRun)
                  ElevatedButton.icon(
                    onPressed: _stopAutoRun,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: const Text('Auto-Run stoppen'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

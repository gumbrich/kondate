import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'coop_basket_service.dart';
import 'coop_saved_product.dart';

/// Browse the live catalogue and explicitly select a detail page. Selecting a
/// product only returns a mapping; the basket service performs later writes.
class CoopProductSelectionScreen extends StatefulWidget {
  const CoopProductSelectionScreen({
    super.key,
    required this.ingredient,
    required this.canonicalKey,
    required this.query,
  });
  final String ingredient, canonicalKey, query;

  @override
  State<CoopProductSelectionScreen> createState() =>
      _CoopProductSelectionScreenState();
}

class _CoopProductSelectionScreenState
    extends State<CoopProductSelectionScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _selecting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) {
              setState(() {
                _loading = true;
                _error = null;
              });
            }
          },
          onPageFinished: (_) {
            if (mounted) {
              setState(() {
                _loading = false;
              });
            }
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame == true &&
                error.errorCode != -999 &&
                mounted) {
              setState(() {
                _loading = false;
                _error =
                    'Coop konnte nicht geladen werden. Bitte erneut suchen.';
              });
            }
          },
        ),
      );
    _search();
  }

  Future<void> _search() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _controller.loadRequest(
        Uri.https('www.coop.ch', '/de/search/', {'text': widget.query}),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Coop konnte nicht geöffnet werden.';
        });
      }
    }
  }

  Future<void> _choose() async {
    setState(() {
      _selecting = true;
      _error = null;
    });
    try {
      final current = await _controller.currentUrl();
      final id = coopProductId(current ?? '');
      if (id == null) {
        throw const FormatException(
          'Bitte zuerst ein einzelnes Produkt in den Suchergebnissen öffnen.',
        );
      }
      final result = decodeCoopResult(
        await _controller.runJavaScriptReturningResult('''
        JSON.stringify((() => {
          const url = location.href;
          const detail = document.querySelector('[data-product-basic-info][data-productid="$id"]');
          const title = detail?.querySelector('h1') || document.querySelector('main h1');
          return {url, productId: detail?.getAttribute('data-productid'),
            title: (title?.innerText || '').trim()};
        })())
      '''),
      );
      final title = result['title'];
      if (result['productId'] != id ||
          coopProductId(result['url'] as String? ?? '') != id ||
          coopProductId(await _controller.currentUrl() ?? '') != id) {
        throw const FormatException(
          'Produktseite noch nicht eindeutig geladen. Bitte kurz warten und erneut auswählen.',
        );
      }
      if (title is! String || title.trim().isEmpty || title.length > 300) {
        throw const FormatException(
          'Produktname konnte nicht gelesen werden. Bitte eine andere Produktseite öffnen.',
        );
      }
      if (!mounted) return;
      // Freeze the reviewed identity before displaying confirmation.
      final uri = Uri.parse(current!);
      final product = CoopSavedProduct(
        canonicalKey: widget.canonicalKey,
        productLabel: title.trim(),
        productUrl: Uri(
          scheme: 'https',
          host: uri.host,
          path: uri.path,
        ).toString(),
      );
      final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Für ${widget.ingredient} verwenden?'),
          content: Text(
            '${product.productLabel}\n\nBitte Packungsgrösse und Variante prüfen. Die Auswahl wird für diese Zutat gemerkt. Erst im nächsten Schritt werden Packungen in den Warenkorb gelegt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Weiter suchen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Dieses Produkt wählen'),
            ),
          ],
        ),
      );
      if (accepted == true && mounted) Navigator.pop(context, product);
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e is FormatException
              ? e.message
              : 'Produkt konnte nicht ausgewählt werden. Bitte erneut versuchen.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _selecting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Coop-Produkt für ${widget.ingredient}')),
    body: Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Öffne das gewünschte Produkt. Bei mehreren Treffern wählst du Marke, Variante und Packungsgrösse selbst.',
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _selecting ? null : _search,
                    child: const Text('Zur Suche'),
                  ),
                  FilledButton(
                    onPressed: _loading || _selecting ? null : _choose,
                    child: const Text('Geöffnetes Produkt auswählen'),
                  ),
                ],
              ),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            ],
          ),
        ),
        if (_loading || _selecting) const LinearProgressIndicator(),
        Expanded(
          child: AbsorbPointer(
            absorbing: _selecting,
            child: WebViewWidget(controller: _controller),
          ),
        ),
      ],
    ),
  );
}

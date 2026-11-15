import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'coop_basket_service.dart';
import 'coop_basket_webview.dart';

enum _Status { pending, verified, manual, skipped, blocked, uncertain }

class CoopAssistantScreen extends StatefulWidget {
  final List<CoopBasketItem> items;

  const CoopAssistantScreen({super.key, required this.items});

  @override
  State<CoopAssistantScreen> createState() => _CoopAssistantScreenState();
}

class _CoopAssistantScreenState extends State<CoopAssistantScreen> {
  late final WebViewController _controller;
  late final CoopBasketWebView _page;
  late final CoopBasketService _service;
  late final List<_Status> _statuses;
  late final List<String?> _messages;
  int _index = 0;
  bool _loading = true;
  bool _running = false;
  bool _cancelRequested = false;

  CoopBasketItem get _current => widget.items[_index];

  @override
  void initState() {
    super.initState();
    _statuses = List<_Status>.filled(widget.items.length, _Status.pending);
    _messages = List<String?>.filled(widget.items.length, null);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted);
    _page = CoopBasketWebView(_controller);
    _service = CoopBasketService(page: _page);
    _controller.setNavigationDelegate(
      NavigationDelegate(
        onPageStarted: (_) {
          if (mounted) setState(() => _loading = true);
        },
        onPageFinished: (_) {
          _page.onPageFinished();
          if (mounted) setState(() => _loading = false);
        },
        onWebResourceError: (WebResourceError error) {
          if (error.isForMainFrame == true) {
            _page.onPageError();
            if (mounted) setState(() => _loading = false);
          }
        },
      ),
    );
    if (widget.items.isNotEmpty) _openIndex(0);
  }

  Future<bool> _openIndex(int index) async {
    if (!mounted) return false;
    setState(() {
      _index = index;
      _loading = true;
    });
    try {
      await _page.open(Uri.parse(_current.product.productUrl));
      return mounted;
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _statuses[index] = _Status.blocked;
          _messages[index] =
              'Coop-Seite konnte nicht geladen werden. Bitte erneut öffnen.';
        });
      }
      return false;
    }
  }

  bool _retryable(int index) =>
      _statuses[index] == _Status.pending ||
      _statuses[index] == _Status.blocked;

  Future<void> _run({bool all = false}) async {
    if (_running || _loading) return;
    setState(() {
      _running = true;
      _cancelRequested = false;
    });
    try {
      final List<int> indices = all
          ? List<int>.generate(
              widget.items.length,
              (int i) => i,
            ).where(_retryable).toList()
          : <int>[_index];
      for (final int index in indices) {
        if (!mounted || _cancelRequested) break;
        if (index != _index && !await _openIndex(index)) break;
        if (!mounted || _cancelRequested) break;
        final CoopBasketItem item = widget.items[index];
        final CoopBasketResult result = await _service.ensureQuantity(
          productUrl: item.product.productUrl,
          targetQuantity: item.targetQuantity,
          isCancelled: () => !mounted || _cancelRequested,
        );
        if (!mounted) break;
        setState(() {
          _messages[index] = result.message;
          _statuses[index] = switch (result.outcome) {
            CoopBasketOutcome.verified => _Status.verified,
            CoopBasketOutcome.blocked => _Status.blocked,
            CoopBasketOutcome.uncertain ||
            CoopBasketOutcome.cancelled => _Status.uncertain,
          };
        });
        if (!result.verified) break;
      }
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  String _label(_Status status) => switch (status) {
    _Status.pending => 'Offen',
    _Status.verified => 'Menge bestätigt',
    _Status.manual => 'Manuell geprüft',
    _Status.skipped => 'Übersprungen',
    _Status.blocked => 'Aktion nötig',
    _Status.uncertain => 'Warenkorb prüfen',
  };

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Coop-Assistent')),
        body: const Center(child: Text('Keine Produkte ausgewählt.')),
      );
    }
    final int verified = _statuses.where((s) => s == _Status.verified).length;
    return Scaffold(
      appBar: AppBar(
        title: Text('Coop-Assistent ${_index + 1}/${widget.items.length}'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Produkt neu öffnen',
            onPressed: _running || _loading ? null : () => _openIndex(_index),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  _current.product.productLabel,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                Text(
                  'Ziel im Warenkorb: ${_current.targetQuantity} Packung(en) insgesamt',
                ),
                Text(
                  '${_label(_statuses[_index])} · $verified/${widget.items.length} automatisch bestätigt',
                ),
                if (_messages[_index] != null) Text(_messages[_index]!),
                const Text(
                  'Bei einer Anmeldung bitte direkt auf der Coop-Seite fortfahren. '
                  'Unklare Ergebnisse werden nicht automatisch wiederholt.',
                ),
              ],
            ),
          ),
          if (_loading || _running) const LinearProgressIndicator(),
          Expanded(
            child: AbsorbPointer(
              absorbing: _running,
              child: WebViewWidget(controller: _controller),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                OutlinedButton(
                  onPressed: _running || _loading || _index == 0
                      ? null
                      : () => _openIndex(_index - 1),
                  child: const Text('Zurück'),
                ),
                FilledButton(
                  onPressed: _running || _loading ? null : () => _run(),
                  child: const Text('Zielmenge prüfen / ergänzen'),
                ),
                FilledButton.tonal(
                  onPressed:
                      _running ||
                          _loading ||
                          !List<int>.generate(
                            widget.items.length,
                            (i) => i,
                          ).any(_retryable)
                      ? null
                      : () => _run(all: true),
                  child: const Text('Offene Produkte bearbeiten'),
                ),
                if (_running)
                  OutlinedButton(
                    onPressed: () => setState(() => _cancelRequested = true),
                    child: const Text('Stoppen'),
                  ),
                OutlinedButton(
                  onPressed:
                      _running || _loading || _index == widget.items.length - 1
                      ? null
                      : () => _openIndex(_index + 1),
                  child: const Text('Weiter'),
                ),
                OutlinedButton(
                  onPressed: _running
                      ? null
                      : () => setState(() {
                          _statuses[_index] = _Status.manual;
                          _messages[_index] =
                              'Menge vom Nutzer im Warenkorb geprüft.';
                        }),
                  child: const Text('Im Warenkorb selbst geprüft'),
                ),
                OutlinedButton(
                  onPressed: _running
                      ? null
                      : () => setState(() {
                          _statuses[_index] = _Status.skipped;
                          _messages[_index] =
                              'Für diesen Durchlauf übersprungen.';
                        }),
                  child: const Text('Überspringen'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

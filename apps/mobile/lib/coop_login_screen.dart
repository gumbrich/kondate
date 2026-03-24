import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class CoopLoginScreen extends StatefulWidget {
  const CoopLoginScreen({super.key});

  @override
  State<CoopLoginScreen> createState() => _CoopLoginScreenState();
}

class _CoopLoginScreenState extends State<CoopLoginScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  String? _pageInfo;

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
          onPageFinished: (_) async {
            if (!mounted) return;
            setState(() {
              _loading = false;
            });
            await _inspectPage();
          },
        ),
      )
      ..loadRequest(Uri.parse('https://www.coop.ch/de/'));
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
        _pageInfo = result.toString();
      });
    } catch (_) {}
  }

  Future<void> _reload() async {
    await _controller.reload();
  }

  void _done() {
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coop-Login'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Neu laden',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Fertig',
            onPressed: _done,
            icon: const Icon(Icons.check),
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
                  const Text(
                    'Bitte hier einmal bei Coop einloggen.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Wichtig: Nicht im externen Browser, sondern direkt hier in der App anmelden. '
                    'Danach mit dem Häkchen oben zurückgehen und erneut den Coop-Assistenten testen.',
                  ),
                  if (_pageInfo != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      _pageInfo!,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          Expanded(
            child: WebViewWidget(controller: _controller),
          ),
        ],
      ),
    );
  }
}

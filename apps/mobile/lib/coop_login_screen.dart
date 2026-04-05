import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'coop_credentials_store.dart';

class CoopLoginScreen extends StatefulWidget {
  const CoopLoginScreen({super.key});

  @override
  State<CoopLoginScreen> createState() => _CoopLoginScreenState();
}

class _CoopLoginScreenState extends State<CoopLoginScreen> {
  late final WebViewController _controller;
  final CoopCredentialsStore _credentialsStore = CoopCredentialsStore();

  bool _loading = true;
  bool _running = false;
  String? _pageInfo;
  String? _lastResult;

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

  Future<void> _fillCredentials() async {
    if (_running) return;

    setState(() {
      _running = true;
    });

    try {
      final CoopCredentials credentials = await _credentialsStore.load();

      if (!credentials.isComplete) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Keine gespeicherten Coop-Zugangsdaten vorhanden'),
          ),
        );
        return;
      }

      final String email = _jsEscape(credentials.email);
      final String password = _jsEscape(credentials.password);

      final String script = '''
(() => {
  function findInput(candidates) {
    for (const selector of candidates) {
      const el = document.querySelector(selector);
      if (el) return el;
    }
    return null;
  }

  function setValue(el, value) {
    if (!el) return false;
    el.focus();
    el.value = value;
    el.dispatchEvent(new Event('input', { bubbles: true }));
    el.dispatchEvent(new Event('change', { bubbles: true }));
    return true;
  }

  const emailInput = findInput([
    'input[type="email"]',
    'input[name="email"]',
    'input[name="username"]',
    'input[id*="email"]',
    'input[id*="user"]'
  ]);

  const passwordInput = findInput([
    'input[type="password"]',
    'input[name="password"]',
    'input[id*="password"]'
  ]);

  const emailOk = setValue(emailInput, '$email');
  const passwordOk = setValue(passwordInput, '$password');

  return JSON.stringify({
    emailFound: !!emailInput,
    passwordFound: !!passwordInput,
    emailFilled: emailOk,
    passwordFilled: passwordOk
  });
})();
''';

      final Object result =
          await _controller.runJavaScriptReturningResult(script);

      if (!mounted) return;
      setState(() {
        _lastResult = result.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Zugangsdaten eingefüllt: $_lastResult'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastResult = 'fill-error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Einfüllen fehlgeschlagen: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }

  Future<void> _submitLogin() async {
    if (_running) return;

    setState(() {
      _running = true;
    });

    const String script = r'''
(() => {
  function normalize(text) {
    return (text || '').replace(/\s+/g, ' ').trim().toLowerCase();
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

  const buttons = Array.from(document.querySelectorAll('button, input[type="submit"], a'));

  const candidates = buttons.filter((el) => {
    if (!visible(el)) return false;
    const text = normalize(
      (el.innerText || '') + ' ' +
      (el.value || '') + ' ' +
      (el.getAttribute('aria-label') || '') + ' ' +
      (el.getAttribute('title') || '')
    );

    return (
      text.includes('anmelden') ||
      text.includes('login') ||
      text.includes('log in') ||
      text.includes('sign in')
    );
  });

  if (candidates.length === 0) {
    return 'no-login-button-match';
  }

  candidates[0].click();
  return 'clicked-login-button';
})();
''';

    try {
      final Object result =
          await _controller.runJavaScriptReturningResult(script);

      if (!mounted) return;
      setState(() {
        _lastResult = result.toString();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login-Aktion: $_lastResult'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _lastResult = 'submit-error: $e';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login-Klick fehlgeschlagen: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _running = false;
        });
      }
    }
  }

  String _jsEscape(String input) {
    return input
        .replaceAll(r'\', r'\\')
        .replaceAll("'", r"\'")
        .replaceAll('\n', r'\n')
        .replaceAll('\r', r'\r');
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
            onPressed: _running ? null : _reload,
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
                    'Bitte hier bei Coop einloggen.',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Du kannst den Login manuell machen oder gespeicherte Zugangsdaten '
                    'automatisch einfüllen lassen.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: _running ? null : _fillCredentials,
                        icon: const Icon(Icons.password),
                        label: const Text('Zugangsdaten einfüllen'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: _running ? null : _submitLogin,
                        icon: const Icon(Icons.login),
                        label: const Text('Login klicken'),
                      ),
                    ],
                  ),
                  if (_pageInfo != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      _pageInfo!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                  if (_lastResult != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      _lastResult!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
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

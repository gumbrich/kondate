import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'coop_basket_scripts.dart';
import 'coop_basket_service.dart';

/// Page callbacks must be wired into the WebView's navigation delegate.
class CoopBasketWebView implements CoopBasketPage {
  final WebViewController controller;
  Completer<void>? _load;
  String? _lastDiagnostic;
  bool _started = false;
  bool _armed = false;

  CoopBasketWebView(this.controller);

  void onPageStarted() {
    if (_armed && _load != null) _started = true;
  }

  void onPageFinished() {
    final Completer<void>? load = _load;
    if (_started && load != null && !load.isCompleted) load.complete();
  }

  void onPageError() {
    final Completer<void>? load = _load;
    if (_armed && load != null && !load.isCompleted) {
      load.completeError(StateError('Page load failed'));
    }
  }

  Future<void> open(Uri url) => _navigate(() => controller.loadRequest(url));

  @override
  Future<void> reload() =>
      _navigate(controller.reload, verifyNewDocument: true);

  Future<void> _navigate(
    Future<void> Function() navigate, {
    bool verifyNewDocument = false,
  }) async {
    if (_load != null) throw StateError('Page navigation already in progress');
    // A late callback from an earlier load must not verify an optimistic DOM.
    final String marker = jsonEncode(
      DateTime.now().microsecondsSinceEpoch.toString(),
    );
    final Completer<void> load = Completer<void>();
    _load = load;
    _started = false;
    _armed = false;
    // Attach the error/timeout handler before a synchronous navigation callback.
    final Future<void> loaded = load.future.timeout(
      const Duration(seconds: 20),
    );
    try {
      Future<void> start() async {
        if (verifyNewDocument) {
          await controller.runJavaScript(
            'window.__kondateOldDocument = $marker;',
          );
        }
        _armed = true;
        await navigate();
      }

      await Future.wait<void>(<Future<void>>[
        start(),
        loaded,
      ], eagerError: true);
      if (!verifyNewDocument) return;
      for (int attempt = 0; attempt < 20; attempt++) {
        final Object oldDocument = await controller
            .runJavaScriptReturningResult(
              'window.__kondateOldDocument === $marker',
            );
        if (oldDocument == false || oldDocument == 'false') return;
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      throw StateError('Navigation did not replace the old document');
    } finally {
      if (!load.isCompleted) load.complete();
      if (identical(_load, load)) {
        _load = null;
        _armed = false;
      }
    }
  }

  @override
  Future<CoopBasketSnapshot> read(String productId) async {
    final Map<String, dynamic> data = decodeCoopResult(
      await controller.runJavaScriptReturningResult(
        CoopBasketScripts.read(productId),
      ),
    );
    if (kDebugMode) {
      // Only SKU/count/selector state: never URLs, cookies, or account content.
      final String diagnostic = jsonEncode(data);
      if (diagnostic != _lastDiagnostic) {
        debugPrint('Coop basket: $diagnostic');
        _lastDiagnostic = diagnostic;
      }
    }
    return CoopBasketSnapshot.fromResult(data);
  }

  @override
  Future<bool> addOne(String productId, int expectedQuantity) async =>
      decodeCoopResult(
        await controller.runJavaScriptReturningResult(
          CoopBasketScripts.addOne(productId, expectedQuantity),
        ),
      )['clicked'] ==
      true;
}

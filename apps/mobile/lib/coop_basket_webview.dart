import 'dart:async';

import 'package:webview_flutter/webview_flutter.dart';

import 'coop_basket_scripts.dart';
import 'coop_basket_service.dart';

/// Page callbacks must be wired into the WebView's navigation delegate.
class CoopBasketWebView implements CoopBasketPage {
  final WebViewController controller;
  Completer<void>? _load;

  CoopBasketWebView(this.controller);

  void onPageFinished() {
    final Completer<void>? load = _load;
    if (load != null && !load.isCompleted) load.complete();
  }

  void onPageError() {
    final Completer<void>? load = _load;
    if (load != null && !load.isCompleted) {
      load.completeError(StateError('Page load failed'));
    }
  }

  Future<void> open(Uri url) => _navigate(() => controller.loadRequest(url));

  @override
  Future<void> reload() => _navigate(controller.reload);

  Future<void> _navigate(Future<void> Function() navigate) async {
    if (_load != null) throw StateError('Page navigation already in progress');
    final Completer<void> load = Completer<void>();
    _load = load;
    // Attach the error/timeout handler before a synchronous navigation callback.
    final Future<void> loaded = load.future.timeout(
      const Duration(seconds: 20),
    );
    try {
      await Future.wait<void>(<Future<void>>[navigate(), loaded]);
    } finally {
      if (identical(_load, load)) _load = null;
    }
  }

  @override
  Future<CoopBasketSnapshot> read(String productId) async =>
      CoopBasketSnapshot.fromResult(
        await controller.runJavaScriptReturningResult(
          CoopBasketScripts.read(productId),
        ),
      );

  @override
  Future<bool> addOne(String productId, int expectedQuantity) async =>
      decodeCoopResult(
        await controller.runJavaScriptReturningResult(
          CoopBasketScripts.addOne(productId, expectedQuantity),
        ),
      )['clicked'] ==
      true;
}

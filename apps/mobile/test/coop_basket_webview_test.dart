import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/coop_basket_webview.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

class FakeWebView extends PlatformWebViewController {
  FakeWebView()
    : super.implementation(const PlatformWebViewControllerCreationParams());
  bool oldDocument = false;
  Future<void> Function()? onReload;
  @override
  Future<void> runJavaScript(String script) async {
    oldDocument = true;
  }

  @override
  Future<Object> runJavaScriptReturningResult(String script) async =>
      oldDocument;
  @override
  Future<void> reload() async {
    await onReload?.call();
  }
}

void main() {
  testWidgets('finish before start cannot complete a reload', (tester) async {
    final platform = FakeWebView();
    final page = CoopBasketWebView(WebViewController.fromPlatform(platform));
    bool finished = false;
    final reload = page.reload().then((_) => finished = true);
    await tester.pump();
    page.onPageFinished();
    await tester.pump();
    expect(finished, isFalse);
    page.onPageStarted();
    platform.oldDocument = false;
    page.onPageFinished();
    await tester.pump();
    await reload;
    expect(finished, isTrue);
  });

  testWidgets('stale finish after start still cannot verify the old document', (
    tester,
  ) async {
    final platform = FakeWebView();
    final page = CoopBasketWebView(WebViewController.fromPlatform(platform));
    bool finished = false;
    platform.onReload = () async {
      page.onPageStarted();
      page.onPageFinished();
    };
    final reload = page.reload().then((_) => finished = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(finished, isFalse);
    platform.oldDocument = false;
    await tester.pump(const Duration(milliseconds: 500));
    await reload;
    expect(finished, isTrue);
  });

  testWidgets('navigation failure returns promptly and clears the load lock', (
    tester,
  ) async {
    final platform = FakeWebView();
    final page = CoopBasketWebView(WebViewController.fromPlatform(platform));
    platform.onReload = () async {
      throw StateError('Cannot load');
    };
    final failure = expectLater(page.reload(), throwsStateError);
    await tester.pump();
    await failure;
    platform.onReload = () async {
      page.onPageStarted();
      platform.oldDocument = false;
      page.onPageFinished();
    };
    final retry = page.reload();
    await tester.pump();
    await retry;
  });
}

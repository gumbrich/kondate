import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/coop_basket_service.dart';

const String productUrl = 'https://www.coop.ch/de/milch/p/3081654';

class FakePage implements CoopBasketPage {
  int persisted = 0;
  int visible = 0;
  int clicks = 0;
  int reloads = 0;
  bool login = false;
  bool loginAfterClick = false;
  bool available = true;
  int addQuantity = 1;
  bool persistClicks = true;
  bool malformed = false;
  bool throwAfterClick = false;
  bool clickRejected = false;
  bool wrongProduct = false;
  int increment = 1;
  bool guardViolation = false;

  @override
  Future<CoopBasketSnapshot> read(String productId) async => CoopBasketSnapshot(
    productId: wrongProduct ? 'other' : productId,
    quantity: malformed ? null : visible,
    ready: !malformed,
    loginRequired: login,
    canAdd: available && addQuantity == 1,
    addQuantity: addQuantity,
  );

  @override
  Future<bool> addOne(String productId, int expectedQuantity) async {
    if (clickRejected) return false;
    if (expectedQuantity != visible) guardViolation = true;
    clicks++;
    if (loginAfterClick) login = true;
    visible += increment;
    if (persistClicks) persisted = visible;
    if (throwAfterClick) throw StateError('Bridge disconnected');
    return true;
  }

  @override
  Future<void> reload() async {
    reloads++;
    visible = persisted;
  }
}

void main() {
  late FakePage page;
  late CoopBasketService service;
  setUp(() {
    page = FakePage();
    service = CoopBasketService(page: page, wait: (_) async {});
  });
  tearDown(() => expect(page.guardViolation, isFalse));

  Future<CoopBasketResult> run([int target = 1]) =>
      service.ensureQuantity(productUrl: productUrl, targetQuantity: target);

  test('verifies each increment against the reloaded page', () async {
    final result = await run(3);
    expect(result.verified, isTrue);
    expect(result.quantity, 3);
    expect(page.clicks, 3);
    expect(page.reloads, 4);
  });

  test('retrying the same target never adds the same packs twice', () async {
    expect((await run(2)).verified, isTrue);
    expect((await run(2)).verified, isTrue);
    expect(page.clicks, 2);
  });

  test('existing quantity is included in the target', () async {
    page.persisted = 2;
    expect((await run(3)).verified, isTrue);
    expect(page.clicks, 1);
  });

  test('a transient counter increase is not reported as success', () async {
    page.persistClicks = false;
    expect((await run()).outcome, CoopBasketOutcome.uncertain);
    expect(page.clicks, 1);
  });

  test('a late success is read before a retry can click again', () async {
    page.persistClicks = false;
    expect((await run()).outcome, CoopBasketOutcome.uncertain);
    page.persisted = 1;
    expect((await run()).verified, isTrue);
    expect(page.clicks, 1);
  });

  test('login and unavailable products stop before any click', () async {
    page.login = true;
    expect((await run()).outcome, CoopBasketOutcome.blocked);
    page.login = false;
    page.available = false;
    expect((await run()).outcome, CoopBasketOutcome.blocked);
    expect(page.clicks, 0);
  });

  test(
    'wrong product and unreadable quantity are not assumed to be zero',
    () async {
      page.wrongProduct = true;
      expect((await run()).outcome, CoopBasketOutcome.blocked);
      page.wrongProduct = false;
      page.malformed = true;
      expect((await run()).outcome, CoopBasketOutcome.blocked);
      expect(page.clicks, 0);
    },
  );

  test('does not silently reduce an existing basket quantity', () async {
    page.persisted = 4;
    expect((await run(2)).outcome, CoopBasketOutcome.blocked);
    expect(page.clicks, 0);
    expect(page.persisted, 4);
  });

  test('unexpected increments and bridge failure stop the run', () async {
    page.increment = 2;
    expect((await run(3)).outcome, CoopBasketOutcome.uncertain);
    expect(page.clicks, 1);
    page.persisted = 0;
    page.throwAfterClick = true;
    expect((await run()).outcome, CoopBasketOutcome.uncertain);
  });

  test('a stale click guard stops without retrying', () async {
    page.clickRejected = true;
    expect((await run()).outcome, CoopBasketOutcome.blocked);
    expect(page.clicks, 0);
  });

  test('multi-pack promotions stop before dispatching a click', () async {
    page.addQuantity = 2;
    expect((await run()).outcome, CoopBasketOutcome.blocked);
    expect(page.clicks, 0);
    // A manually prepared matching quantity can still be verified.
    page.persisted = 1;
    expect((await run()).verified, isTrue);
  });

  test('login loss after dispatch leaves the write uncertain', () async {
    page.loginAfterClick = true;
    expect((await run(3)).outcome, CoopBasketOutcome.uncertain);
    expect(page.clicks, 1);
  });

  test(
    'cancellation after a dispatched action prevents further clicks',
    () async {
      final service = CoopBasketService(page: page, wait: (_) async {});
      final result = await service.ensureQuantity(
        productUrl: productUrl,
        targetQuantity: 3,
        isCancelled: () => page.clicks == 1,
      );
      expect(result.outcome, CoopBasketOutcome.cancelled);
      expect(page.clicks, 1);
    },
  );

  test('cancelling before dispatch is safely retryable', () async {
    final result = await service.ensureQuantity(
      productUrl: productUrl,
      targetQuantity: 1,
      isCancelled: () => true,
    );
    expect(result.outcome, CoopBasketOutcome.blocked);
    expect(page.clicks, 0);
    expect(page.reloads, 0);
  });

  test('invalid targets and URLs perform no page actions', () async {
    for (final target in <int>[0, -1, 21]) {
      expect((await run(target)).outcome, CoopBasketOutcome.blocked);
    }
    for (final url in <String>[
      'https://coop.ch.evil.example/p/123',
      'http://www.coop.ch/p/123',
      'https://www.coop.ch:444/p/123',
      'https://user@www.coop.ch/p/123',
      'https://www.coop.ch/de/search/?text=milch',
    ]) {
      expect(
        (await service.ensureQuantity(
          productUrl: url,
          targetQuantity: 1,
        )).outcome,
        CoopBasketOutcome.blocked,
      );
    }
    expect(page.reloads, 0);
    expect(page.clicks, 0);
  });

  test('decodes both native and Android JSON bridge results', () {
    final data = <String, dynamic>{
      'productId': '3081654',
      'quantity': 2,
      'ready': true,
    };
    for (final value in <Object>[
      data,
      jsonEncode(data),
      jsonEncode(jsonEncode(data)),
    ]) {
      expect(CoopBasketSnapshot.fromResult(value).quantity, 2);
    }
    expect(() => decodeCoopResult('null'), throwsFormatException);
    expect(
      CoopBasketSnapshot.fromResult(<String, dynamic>{
        'quantity': '1.90 CHF',
      }).quantity,
      isNull,
    );
  });
}

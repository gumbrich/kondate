import 'dart:convert';

import 'coop_saved_product.dart';

/// Counts are total packs wanted in the basket, not an increment on each retry.
class CoopBasketItem {
  final CoopSavedProduct product;
  final int targetQuantity;

  const CoopBasketItem({required this.product, required this.targetQuantity});
}

String? coopProductId(String url) {
  final Uri? uri = Uri.tryParse(url);
  if (uri == null ||
      uri.scheme != 'https' ||
      !const <String>{'coop.ch', 'www.coop.ch'}.contains(uri.host) ||
      uri.userInfo.isNotEmpty ||
      uri.port != 443) {
    return null;
  }
  return RegExp(r'/p/(\d+)/?$').firstMatch(uri.path)?.group(1);
}

/// WKWebView and Android may return JSON strings at different encoding depths.
Map<String, dynamic> decodeCoopResult(Object value) {
  dynamic decoded = value;
  for (int i = 0; i < 3 && decoded is String; i++) {
    decoded = jsonDecode(decoded);
  }
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Invalid Coop page response');
  }
  return decoded;
}

class CoopBasketSnapshot {
  final String productId;
  final int? quantity;
  final bool ready;
  final bool loginRequired;
  final bool canAdd;

  const CoopBasketSnapshot({
    required this.productId,
    required this.quantity,
    required this.ready,
    this.loginRequired = false,
    this.canAdd = false,
  });

  factory CoopBasketSnapshot.fromResult(Object value) {
    final Map<String, dynamic> data = decodeCoopResult(value);
    final dynamic quantity = data['quantity'];
    return CoopBasketSnapshot(
      productId: data['productId'] as String? ?? '',
      quantity: quantity is int && quantity >= 0 ? quantity : null,
      ready: data['ready'] == true,
      loginRequired: data['loginRequired'] == true,
      canAdd: data['canAdd'] == true,
    );
  }
}

enum CoopBasketOutcome { verified, blocked, uncertain, cancelled }

class CoopBasketResult {
  final CoopBasketOutcome outcome;
  final String message;
  final int? quantity;

  const CoopBasketResult(this.outcome, this.message, [this.quantity]);

  bool get verified => outcome == CoopBasketOutcome.verified;
}

abstract class CoopBasketPage {
  Future<CoopBasketSnapshot> read(String productId);
  Future<bool> addOne(String productId, int expectedQuantity);
  Future<void> reload();
}

/// A click is never proof. Verify the product's count on a reloaded page.
class CoopBasketService {
  final CoopBasketPage page;
  final Future<void> Function(Duration) wait;

  CoopBasketService({required this.page, Future<void> Function(Duration)? wait})
    : wait = wait ?? Future<void>.delayed;

  Future<CoopBasketSnapshot?> _settled(
    String id,
    bool Function() cancelled,
  ) async {
    CoopBasketSnapshot? previous;
    for (int i = 0; i < 20; i++) {
      if (cancelled()) return null;
      final CoopBasketSnapshot state = await page.read(id);
      if (cancelled()) return null;
      if (state.loginRequired) return state;
      if (state.ready && state.productId == id && state.quantity != null) {
        if (previous?.quantity == state.quantity &&
            previous?.productId == state.productId &&
            previous?.canAdd == state.canAdd) {
          return state;
        }
        previous = state;
      } else {
        previous = null;
      }
      await wait(const Duration(milliseconds: 500));
    }
    return null;
  }

  Future<CoopBasketResult> ensureQuantity({
    required String productUrl,
    required int targetQuantity,
    bool Function()? isCancelled,
  }) async {
    final bool Function() cancelled = isCancelled ?? () => false;
    final String? id = coopProductId(productUrl);
    if (id == null || targetQuantity < 1 || targetQuantity > 20) {
      return const CoopBasketResult(
        CoopBasketOutcome.blocked,
        'Bitte einen Coop-Produktlink und 1 bis 20 Packungen wählen.',
      );
    }
    bool actionMayHaveRun = false;
    try {
      if (cancelled()) return _cancelled;
      // Refresh also on retries: a previous action may have succeeded late.
      await page.reload();
      CoopBasketSnapshot? state = await _settled(id, cancelled);
      while (!cancelled()) {
        if (state?.loginRequired == true) {
          return CoopBasketResult(
            actionMayHaveRun
                ? CoopBasketOutcome.uncertain
                : CoopBasketOutcome.blocked,
            actionMayHaveRun
                ? 'Anmeldung unterbrochen. Bitte anmelden und Warenkorb prüfen; '
                      'eine Aktion kann bereits angekommen sein.'
                : 'Bitte hier bei Coop anmelden und danach erneut prüfen.',
          );
        }
        if (state == null) {
          return CoopBasketResult(
            actionMayHaveRun
                ? CoopBasketOutcome.uncertain
                : CoopBasketOutcome.blocked,
            'Produktmenge nicht lesbar. Bitte den Warenkorb prüfen.',
          );
        }
        final int quantity = state.quantity!;
        if (quantity == targetQuantity) {
          return CoopBasketResult(
            CoopBasketOutcome.verified,
            '$quantity Packung(en) nach Neuladen bestätigt.',
            quantity,
          );
        }
        if (quantity > targetQuantity) {
          return CoopBasketResult(
            CoopBasketOutcome.blocked,
            'Bereits $quantity Packungen im Warenkorb; Ziel: $targetQuantity. '
            'Bitte die Menge bei Coop prüfen.',
            quantity,
          );
        }
        if (!state.canAdd) {
          return CoopBasketResult(
            CoopBasketOutcome.blocked,
            'Hinzufügen derzeit nicht möglich. Bitte Verfügbarkeit prüfen.',
            quantity,
          );
        }
        if (cancelled()) return _cancelled;
        // If the bridge fails after dispatch, the click may still have happened.
        actionMayHaveRun = true;
        final bool clicked = await page.addOne(id, quantity);
        if (!clicked) {
          return const CoopBasketResult(
            CoopBasketOutcome.blocked,
            'Seite oder Menge hat sich geändert. Bitte erneut prüfen.',
          );
        }
        await wait(const Duration(milliseconds: 1500));
        if (cancelled()) return _cancelled;
        await page.reload();
        state = await _settled(id, cancelled);
        if (cancelled()) return _cancelled;
        if (state?.loginRequired == true) continue;
        if (state == null || state.quantity != quantity + 1) {
          return CoopBasketResult(
            CoopBasketOutcome.uncertain,
            'Änderung nicht eindeutig bestätigt. Bitte Warenkorb prüfen, '
            'bevor erneut hinzugefügt wird.',
            state?.quantity,
          );
        }
      }
      return _cancelled;
    } catch (_) {
      return CoopBasketResult(
        actionMayHaveRun
            ? CoopBasketOutcome.uncertain
            : CoopBasketOutcome.blocked,
        'Coop-Seite konnte nicht geprüft werden. Bitte Warenkorb kontrollieren.',
      );
    }
  }

  static const CoopBasketResult _cancelled = CoopBasketResult(
    CoopBasketOutcome.cancelled,
    'Gestoppt. Eine bereits ausgelöste Aktion kann noch ankommen; Warenkorb prüfen.',
  );
}

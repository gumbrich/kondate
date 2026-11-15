import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'coop_cart_prep_screen.dart';
import 'coop_credentials_screen.dart';
import 'coop_login_screen.dart';
import 'coop_preferences_screen.dart';
import 'coop_product_webview_screen.dart';
import 'coop_saved_product.dart';
import 'coop_saved_products_screen.dart';
import 'coop_saved_products_store.dart';
import 'coop_user_preferences.dart';
import 'coop_user_preferences_store.dart';
import 'ingredient_formatter.dart';
import 'purchasable_item.dart';
import 'shopping_purchase_plan.dart';
import 'photo_week_plan.dart';

class ShopPreviewScreen extends StatefulWidget {
  final KondateAppState appState;

  const ShopPreviewScreen({super.key, required this.appState});

  @override
  State<ShopPreviewScreen> createState() => _ShopPreviewScreenState();
}

class _ShopPreviewScreenState extends State<ShopPreviewScreen> {
  final CoopUserPreferencesStore _preferencesStore = CoopUserPreferencesStore();
  final CoopSavedProductsStore _savedProductsStore = CoopSavedProductsStore();

  bool _loading = true;
  Map<String, CoopUserPreferenceOverride> _overrides =
      <String, CoopUserPreferenceOverride>{};
  Map<String, CoopSavedProduct> _savedProducts = <String, CoopSavedProduct>{};

  @override
  void initState() {
    super.initState();
    _loadAll();
  }

  Future<void> _loadAll() async {
    final Map<String, CoopUserPreferenceOverride> overrides =
        await _preferencesStore.loadOverrides();
    final Map<String, CoopSavedProduct> savedProducts =
        await _savedProductsStore.loadSavedProducts();

    if (!mounted) return;
    setState(() {
      _overrides = overrides;
      _savedProducts = savedProducts;
      _loading = false;
    });
  }

  Future<void> _openPreferences() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CoopPreferencesScreen()),
    );
    await _loadAll();
  }

  Future<void> _openSavedProducts() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CoopSavedProductsScreen()),
    );
    await _loadAll();
  }

  Future<void> _openCredentials() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const CoopCredentialsScreen()),
    );
  }

  Future<void> _openCartPrep(List<PurchasableItem> items) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => CoopCartPrepScreen(items: items)),
    );
    await _loadAll();
  }

  Future<void> _openSavedProductInWebView(CoopSavedProduct product) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CoopProductWebViewScreen(
          title: product.productLabel,
          productUrl: product.productUrl,
        ),
      ),
    );
  }

  Future<void> _openCoopLogin() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const CoopLoginScreen()));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final purchasableItems = buildShoppingPurchases(
      widget.appState,
      overrides: _overrides,
    );
    final missingMeals = mealsMissingIngredients(widget.appState);

    final Map<PurchasableCategory, List<PurchasableItem>> grouped =
        _groupByCategory(purchasableItems);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop-Vorschau'),
        actions: <Widget>[
          IconButton(
            onPressed: _openCredentials,
            icon: const Icon(Icons.lock_outline),
            tooltip: 'Coop-Zugangsdaten',
          ),
          IconButton(
            onPressed: _openCoopLogin,
            icon: const Icon(Icons.login),
            tooltip: 'Coop-Login',
          ),
          IconButton(
            onPressed: _openSavedProducts,
            icon: const Icon(Icons.bookmark_outline),
            tooltip: 'Gespeicherte Produkte',
          ),
          IconButton(
            onPressed: _openPreferences,
            icon: const Icon(Icons.tune),
            tooltip: 'Coop-Präferenzen',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Vorbereitung für Shop-Integration',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Hier siehst du kaufbare Artikel mit Coop-orientierten Suchbegriffen, '
                    'Produktprofilen und – wenn vorhanden – gespeicherten Standardprodukten.',
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      FilledButton.icon(
                        onPressed: _openCredentials,
                        icon: const Icon(Icons.lock_outline),
                        label: const Text('Zugangsdaten speichern'),
                      ),
                      FilledButton.icon(
                        onPressed: _openCoopLogin,
                        icon: const Icon(Icons.login),
                        label: const Text('Bei Coop einloggen'),
                      ),
                      FilledButton.tonalIcon(
                        onPressed: purchasableItems.isEmpty
                            ? null
                            : () => _openCartPrep(purchasableItems),
                        icon: const Icon(Icons.shopping_cart_outlined),
                        label: const Text('Warenkorb vorbereiten'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (missingMeals.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text(
                  'Noch ohne Rezept/Zutaten: ${missingMeals.map((d) => weekdayLabels[d]).join(', ')}. Diese Mahlzeiten sind noch nicht in der Einkaufsliste. Bitte im Wochenplan ein Rezept zuordnen oder Zutaten manuell ergänzen.',
                ),
              ),
            ),
          if (purchasableItems.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Noch keine kaufbaren Artikel ableitbar.'),
            ),
          for (final PurchasableCategory category in PurchasableCategory.values)
            if (grouped.containsKey(category)) ...<Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Text(
                  _categoryLabel(category),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              ...grouped[category]!.map((PurchasableItem item) {
                final String canonicalKey =
                    IngredientFormatter.canonicalMergeName(item.displayName);
                final CoopSavedProduct? savedProduct =
                    _savedProducts[canonicalKey];

                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        ListTile(
                          title: Text(item.displayName),
                          subtitle: Text(
                            _subtitleFor(
                              item: item,
                              savedProduct: savedProduct,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 16,
                            right: 16,
                            bottom: 12,
                          ),
                          child: Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
                              if (savedProduct != null &&
                                  savedProduct.productUrl.trim().isNotEmpty)
                                FilledButton.icon(
                                  onPressed: () =>
                                      _openSavedProductInWebView(savedProduct),
                                  icon: const Icon(Icons.smart_display),
                                  label: const Text('Im WebView öffnen'),
                                ),
                              if (savedProduct != null &&
                                  savedProduct.productUrl.trim().isNotEmpty)
                                FilledButton.tonalIcon(
                                  onPressed: () =>
                                      _openDirectUrl(savedProduct.productUrl),
                                  icon: const Icon(Icons.open_in_new),
                                  label: const Text('Extern öffnen'),
                                ),
                              ElevatedButton.icon(
                                onPressed: () =>
                                    _openCoopSearch(item.coopSearchQuery),
                                icon: const Icon(Icons.storefront_outlined),
                                label: const Text('Bei Coop suchen'),
                              ),
                              if (item.coopPreferredSearchQuery != null &&
                                  item.coopPreferredSearchQuery!.isNotEmpty)
                                FilledButton.tonalIcon(
                                  onPressed: () => _openCoopSearch(
                                    item.coopPreferredSearchQuery!,
                                  ),
                                  icon: const Icon(Icons.star_outline),
                                  label: const Text('Bevorzugt suchen'),
                                ),
                              OutlinedButton.icon(
                                onPressed: () =>
                                    _openGenericWebSearch(item.shopSearchQuery),
                                icon: const Icon(Icons.search),
                                label: const Text('Websuche'),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
        ],
      ),
    );
  }

  static Future<void> _openDirectUrl(String url) async {
    final Uri uri = Uri.parse(url);
    await _launchExternalUri(uri);
  }

  static Future<void> _openCoopSearch(String query) async {
    final Uri uri = Uri.https('www.coop.ch', '/de/search/', <String, String>{
      'text': query,
    });

    await _launchExternalUri(uri);
  }

  static Future<void> _openGenericWebSearch(String query) async {
    final Uri uri = Uri.https('www.google.com', '/search', <String, String>{
      'q': query,
    });

    await _launchExternalUri(uri);
  }

  static Future<void> _launchExternalUri(Uri uri) async {
    final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) {
      throw Exception('Konnte URL nicht öffnen: $uri');
    }
  }

  static Map<PurchasableCategory, List<PurchasableItem>> _groupByCategory(
    List<PurchasableItem> items,
  ) {
    final Map<PurchasableCategory, List<PurchasableItem>> grouped =
        <PurchasableCategory, List<PurchasableItem>>{};

    for (final PurchasableItem item in items) {
      grouped.putIfAbsent(item.category, () => <PurchasableItem>[]).add(item);
    }

    return grouped;
  }

  static String _categoryLabel(PurchasableCategory category) {
    switch (category) {
      case PurchasableCategory.gemuese:
        return 'Gemüse';
      case PurchasableCategory.obst:
        return 'Obst';
      case PurchasableCategory.fleisch:
        return 'Fleisch';
      case PurchasableCategory.fisch:
        return 'Fisch';
      case PurchasableCategory.milchprodukte:
        return 'Milchprodukte';
      case PurchasableCategory.trockenwaren:
        return 'Trockenwaren';
      case PurchasableCategory.konserven:
        return 'Konserven';
      case PurchasableCategory.gewuerze:
        return 'Gewürze & Basis';
      case PurchasableCategory.getraenke:
        return 'Getränke';
      case PurchasableCategory.sonstiges:
        return 'Sonstiges';
    }
  }

  static String _subtitleFor({
    required PurchasableItem item,
    required CoopSavedProduct? savedProduct,
  }) {
    final String quantityText = item.quantity == item.quantity.roundToDouble()
        ? item.quantity.toInt().toString()
        : item.quantity.toStringAsFixed(2).replaceAll('.', ',');

    final List<String> lines = <String>[
      item.amountDescription != null
          ? item.amountDescription!
          : item.unit.isEmpty
          ? 'Menge: $quantityText'
          : 'Menge: $quantityText ${item.unit}',
      'Allgemeine Suche: ${item.shopSearchQuery}',
      'Coop-Suche: ${item.coopSearchQuery}',
    ];

    if (savedProduct != null) {
      lines.add('Gespeichertes Produkt: ${savedProduct.productLabel}');
      lines.add('Gespeicherter Link: ${savedProduct.productUrl}');
    }

    if (item.coopPreferredProductLabel != null &&
        item.coopPreferredProductLabel!.isNotEmpty) {
      lines.add('Bevorzugtes Profil: ${item.coopPreferredProductLabel}');
    }

    if (item.coopPreferredSearchQuery != null &&
        item.coopPreferredSearchQuery!.isNotEmpty) {
      lines.add('Bevorzugte Coop-Suche: ${item.coopPreferredSearchQuery}');
    }

    if (item.preferredPackage != null && item.preferredPackage!.isNotEmpty) {
      lines.add('Bevorzugte Packung: ${item.preferredPackage}');
    }

    if (item.purchaseHeuristic != null && item.purchaseHeuristic!.isNotEmpty) {
      lines.add('Strategie: ${item.purchaseHeuristic}');
    }

    if (item.note != null && item.note!.isNotEmpty) {
      lines.add('Hinweis: ${item.note}');
    }

    return lines.join('\n');
  }
}

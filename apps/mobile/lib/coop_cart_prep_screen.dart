import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'coop_assistant_screen.dart';
import 'coop_saved_product.dart';
import 'coop_saved_products_store.dart';
import 'ingredient_formatter.dart';
import 'purchasable_item.dart';

class CoopCartPrepScreen extends StatefulWidget {
  final List<PurchasableItem> items;

  const CoopCartPrepScreen({
    super.key,
    required this.items,
  });

  @override
  State<CoopCartPrepScreen> createState() => _CoopCartPrepScreenState();
}

class _CoopCartPrepScreenState extends State<CoopCartPrepScreen> {
  late final Map<int, bool> _selected;

  @override
  void initState() {
    super.initState();
    _selected = <int, bool>{
      for (int i = 0; i < widget.items.length; i++) i: true,
    };
  }

  List<PurchasableItem> get _selectedItems {
    final List<PurchasableItem> result = <PurchasableItem>[];
    for (int i = 0; i < widget.items.length; i++) {
      if (_selected[i] ?? false) {
        result.add(widget.items[i]);
      }
    }
    return result;
  }

  String _quantityText(PurchasableItem item) {
    final String q = item.quantity == item.quantity.roundToDouble()
        ? item.quantity.toInt().toString()
        : item.quantity.toStringAsFixed(2).replaceAll('.', ',');

    return item.unit.isEmpty ? q : '$q ${item.unit}';
  }

  String _searchQuery(PurchasableItem item) {
    return (item.coopPreferredSearchQuery != null &&
            item.coopPreferredSearchQuery!.trim().isNotEmpty)
        ? item.coopPreferredSearchQuery!
        : item.coopSearchQuery;
  }

  Future<void> _openCoopSearch(String query) async {
    final Uri uri = Uri.https(
      'www.coop.ch',
      '/de/search/',
      <String, String>{'text': query},
    );

    final bool ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!ok) {
      throw Exception('Konnte URL nicht öffnen: $uri');
    }
  }

  Future<void> _openAssistant() async {
    final CoopSavedProductsStore store = CoopSavedProductsStore();
    final Map<String, CoopSavedProduct> saved =
        await store.loadSavedProducts();

    final List<CoopSavedProduct> products = <CoopSavedProduct>[];

    for (final PurchasableItem item in _selectedItems) {
      final String canonicalKey =
          IngredientFormatter.canonicalMergeName(item.displayName);
      final CoopSavedProduct? savedProduct = saved[canonicalKey];

      if (savedProduct != null && savedProduct.productUrl.trim().isNotEmpty) {
        products.add(savedProduct);
      }
    }

    if (!mounted) return;

    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Für die ausgewählten Artikel sind keine gespeicherten Coop-Produkte vorhanden.',
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CoopAssistantScreen(products: products),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<PurchasableItem> selectedItems = _selectedItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coop-Warenkorb vorbereiten'),
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
                    'Vorbereitungsliste',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Ausgewählt: ${selectedItems.length} von ${widget.items.length}',
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: selectedItems.isEmpty ? null : _openAssistant,
                    icon: const Icon(Icons.auto_mode),
                    label: const Text('Coop-Assistent starten'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          ...List<Widget>.generate(widget.items.length, (int index) {
            final PurchasableItem item = widget.items[index];
            final bool checked = _selected[index] ?? false;

            final String searchQuery = _searchQuery(item);

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  children: <Widget>[
                    CheckboxListTile(
                      value: checked,
                      onChanged: (bool? value) {
                        setState(() {
                          _selected[index] = value ?? false;
                        });
                      },
                      title: Text(item.displayName),
                      subtitle: Text(
                        'Menge: ${_quantityText(item)}\n'
                        'Suche: $searchQuery'
                        '${item.coopPreferredProductLabel != null && item.coopPreferredProductLabel!.isNotEmpty ? '\nProfil: ${item.coopPreferredProductLabel}' : ''}',
                      ),
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(
                        left: 16,
                        right: 16,
                        bottom: 12,
                      ),
                      child: Row(
                        children: <Widget>[
                          FilledButton.tonalIcon(
                            onPressed: checked
                                ? () => _openCoopSearch(searchQuery)
                                : null,
                            icon: const Icon(Icons.storefront_outlined),
                            label: const Text('Einzeln öffnen'),
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
      ),
    );
  }
}

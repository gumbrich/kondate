import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'coop_assistant_screen.dart';
import 'coop_basket_service.dart';
import 'coop_saved_product.dart';
import 'coop_saved_products_store.dart';
import 'ingredient_formatter.dart';
import 'purchasable_item.dart';

class CoopCartPrepScreen extends StatefulWidget {
  final List<PurchasableItem> items;

  const CoopCartPrepScreen({super.key, required this.items});

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
    final Uri uri = Uri.https('www.coop.ch', '/de/search/', <String, String>{
      'text': query,
    });

    final bool ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!ok) {
      throw Exception('Konnte URL nicht öffnen: $uri');
    }
  }

  Future<void> _openAssistant() async {
    final CoopSavedProductsStore store = CoopSavedProductsStore();
    final Map<String, CoopSavedProduct> saved = await store.loadSavedProducts();

    final Map<String, CoopSavedProduct> products = <String, CoopSavedProduct>{};
    int missing = 0;
    int merged = 0;
    for (final PurchasableItem item in _selectedItems) {
      final String key = IngredientFormatter.canonicalMergeName(
        item.displayName,
      );
      final CoopSavedProduct? product = saved[key];
      final String? id = product == null
          ? null
          : coopProductId(product.productUrl);
      if (product != null && id != null) {
        if (products.containsKey(id)) merged++;
        products[id] = product;
      } else {
        missing++;
      }
    }
    if (!mounted) return;
    if (products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bitte zuerst gültige Coop-Produktlinks speichern.'),
        ),
      );
      return;
    }
    final Map<String, int> targets = <String, int>{
      for (final id in products.keys) id: 1,
    };
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter update) => AlertDialog(
          title: const Text('Packungen im Warenkorb'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Bitte die gewünschte Gesamtzahl je Coop-Produkt wählen. '
                    'Bereits vorhandene Packungen zählen mit. Zutatenmengen werden '
                    'noch nicht automatisch in Packungen umgerechnet.',
                  ),
                  if (merged > 0)
                    Text(
                      '$merged Zuordnungen zum gleichen Coop-Produkt wurden zusammengefasst. Bitte die Gesamtmenge dafür wählen.',
                    ),
                  if (missing > 0)
                    Text(
                      '$missing ausgewählte Artikel ohne gültigen '
                      'Produktlink werden ausgelassen.',
                    ),
                  for (final MapEntry<String, CoopSavedProduct> entry
                      in products.entries)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SizedBox(height: 12),
                        Text(entry.value.productLabel),
                        Row(
                          children: <Widget>[
                            IconButton(
                              tooltip: 'Weniger Packungen',
                              onPressed: targets[entry.key]! <= 1
                                  ? null
                                  : () => update(
                                      () => targets[entry.key] =
                                          targets[entry.key]! - 1,
                                    ),
                              icon: const Icon(Icons.remove),
                            ),
                            Text('${targets[entry.key]} Packung(en)'),
                            IconButton(
                              tooltip: 'Mehr Packungen',
                              onPressed: targets[entry.key]! >= 20
                                  ? null
                                  : () => update(
                                      () => targets[entry.key] =
                                          targets[entry.key]! + 1,
                                    ),
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ],
                    ),
                  TextButton.icon(
                    onPressed: () async {
                      final CoopSavedProduct? product = await _extraProduct();
                      if (product == null || !context.mounted) return;
                      final String id = coopProductId(product.productUrl)!;
                      update(() {
                        products[id] = product;
                        targets.putIfAbsent(id, () => 1);
                      });
                    },
                    icon: const Icon(Icons.add_link),
                    label: const Text(
                      'Weiteres Coop-Produkt für diesen Einkauf',
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Assistent öffnen'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || confirmed != true) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CoopAssistantScreen(
          items: <CoopBasketItem>[
            for (final entry in products.entries)
              CoopBasketItem(
                product: entry.value,
                targetQuantity: targets[entry.key]!,
              ),
          ],
        ),
      ),
    );
  }

  Future<CoopSavedProduct?> _extraProduct() async {
    String name = '';
    String link = '';
    final GlobalKey<FormState> form = GlobalKey<FormState>();
    return showDialog<CoopSavedProduct>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Weiteres Coop-Produkt'),
        content: SizedBox(
          width: 480,
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  onChanged: (value) => name = value,
                  decoration: const InputDecoration(labelText: 'Produktname'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Bitte einen Namen eingeben.'
                      : null,
                ),
                TextFormField(
                  onChanged: (value) => link = value,
                  decoration: const InputDecoration(
                    labelText: 'Coop-Produktlink',
                  ),
                  validator: (value) =>
                      coopProductId(value?.trim() ?? '') == null
                      ? 'Bitte einen gültigen Coop-Produktlink eingeben.'
                      : null,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Nur für diesen Einkauf. Gespeicherte Produkte und Rezepte bleiben unverändert.',
                ),
              ],
            ),
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              final Uri url = Uri.parse(link.trim());
              // Tracking parameters are not needed to identify the SKU.
              final String cleanUrl = Uri(
                scheme: url.scheme,
                host: url.host,
                path: url.path,
              ).toString();
              Navigator.pop(
                context,
                CoopSavedProduct(
                  canonicalKey: 'coop:${coopProductId(cleanUrl)}',
                  productLabel: name.trim(),
                  productUrl: cleanUrl,
                ),
              );
            },
            child: const Text('Übernehmen'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<PurchasableItem> selectedItems = _selectedItems;

    return Scaffold(
      appBar: AppBar(title: const Text('Coop-Warenkorb vorbereiten')),
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
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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

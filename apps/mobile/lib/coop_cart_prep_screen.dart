import 'package:flutter/material.dart';

import 'coop_assistant_screen.dart';
import 'coop_product_selection_screen.dart';
import 'coop_basket_service.dart';
import 'coop_saved_product.dart';
import 'coop_saved_products_store.dart';
import 'ingredient_formatter.dart';
import 'purchasable_item.dart';

class CoopCartPrepScreen extends StatefulWidget {
  final List<PurchasableItem> items;

  final CoopSavedProductsStore? productStore;
  final Future<CoopSavedProduct?> Function(PurchasableItem)? chooseProduct;
  final Widget Function(List<CoopBasketItem>)? assistantBuilder;

  const CoopCartPrepScreen({
    super.key,
    required this.items,
    this.productStore,
    this.chooseProduct,
    this.assistantBuilder,
  });

  @override
  State<CoopCartPrepScreen> createState() => _CoopCartPrepScreenState();
}

class _CoopCartPrepScreenState extends State<CoopCartPrepScreen> {
  late final Map<int, bool> _selected;
  late final _store = widget.productStore ?? CoopSavedProductsStore();
  Map<String, CoopSavedProduct> _saved = {};
  bool _loading = true;
  bool _busy = false;
  String? _error;

  Future<void> _load() async {
    try {
      final saved = await _store.loadSavedProducts();
      if (mounted) {
        setState(() {
          _saved = saved;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Gespeicherte Produkte konnten nicht geladen werden.';
        });
      }
    }
  }

  String _key(PurchasableItem item) =>
      IngredientFormatter.canonicalMergeName(item.displayName);

  Future<void> _chooseProduct(PurchasableItem item) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final navigator = Navigator.of(context);
      final product = widget.chooseProduct != null
          ? await widget.chooseProduct!(item)
          : await navigator.push<CoopSavedProduct>(
              MaterialPageRoute(
                builder: (_) => CoopProductSelectionScreen(
                  ingredient: item.displayName,
                  canonicalKey: _key(item),
                  query: _searchQuery(item),
                ),
              ),
            );
      if (product == null || !mounted) return;
      if (coopProductId(product.productUrl) == null ||
          product.canonicalKey != _key(item)) {
        throw const FormatException('Ungültige Produktzuordnung.');
      }
      await _store.saveProduct(product);
      if (mounted) {
        setState(() {
          _saved[_key(item)] = product;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error =
              'Produktauswahl konnte nicht gespeichert werden. Bitte erneut versuchen.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _selected = <int, bool>{
      for (int i = 0; i < widget.items.length; i++) i: true,
    };
    _load();
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
    if (item.amountDescription != null) return item.amountDescription!;
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

  Future<void> _openAssistant() async {
    final saved = _saved;
    final missingNames = <String>[];
    final requirements = <String, List<String>>{};

    final Map<String, CoopSavedProduct> products = <String, CoopSavedProduct>{};
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
        (requirements[id] ??= []).add(
          '${item.displayName}: ${_quantityText(item)}',
        );
      } else {
        missingNames.add(item.displayName);
      }
    }
    if (!mounted) return;
    if (missingNames.isNotEmpty) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Für jede Zutat ein Produkt wählen'),
          content: Text(
            'Noch offen: ${missingNames.join(', ')}.\n\nBitte unten ein Coop-Produkt auswählen oder die Zutat bewusst abwählen. Es wird nichts ausgelassen oder hinzugefügt.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Produkte auswählen'),
            ),
          ],
        ),
      );
      return;
    }
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
                  for (final MapEntry<String, CoopSavedProduct> entry
                      in products.entries)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        const SizedBox(height: 12),
                        Text(entry.value.productLabel),
                        Text((requirements[entry.key] ?? []).join('\n')),
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
                        requirements.putIfAbsent(
                          id,
                          () => ['Zusätzlich gewählt'],
                        );
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
    final basketItems = <CoopBasketItem>[
      for (final entry in products.entries)
        CoopBasketItem(
          product: entry.value,
          targetQuantity: targets[entry.key]!,
        ),
    ];
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            widget.assistantBuilder?.call(basketItems) ??
            CoopAssistantScreen(items: basketItems),
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

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Coop-Warenkorb vorbereiten')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
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
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _selected.updateAll((_, _) => true);
                              }),
                        child: const Text('Alle auswählen'),
                      ),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                _selected.updateAll((_, _) => false);
                              }),
                        child: const Text('Alle abwählen'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: selectedItems.isEmpty || _busy
                        ? null
                        : _openAssistant,
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
                      onChanged: _busy
                          ? null
                          : (bool? value) {
                              setState(() {
                                _selected[index] = value ?? false;
                              });
                            },
                      title: Text(item.displayName),
                      subtitle: Text(
                        'Menge: ${_quantityText(item)}\n'
                        'Produkt: ${_saved[_key(item)]?.productLabel ?? 'Noch auswählen'}${_saved[_key(item)] != null && coopProductId(_saved[_key(item)]!.productUrl) == null ? ' (ungültiger Link)' : ''}\n'
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
                            onPressed: checked && !_busy
                                ? () => _chooseProduct(item)
                                : null,
                            icon: const Icon(Icons.storefront_outlined),
                            label: Text(
                              _saved.containsKey(_key(item))
                                  ? 'Anderes Produkt wählen'
                                  : 'Coop-Produkt auswählen',
                            ),
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

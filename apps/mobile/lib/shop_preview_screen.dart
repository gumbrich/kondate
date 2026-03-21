import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'ingredient_formatter.dart';
import 'purchasable_item.dart';
import 'purchasable_item_mapper.dart';

class ShopPreviewScreen extends StatelessWidget {
  final KondateAppState appState;

  const ShopPreviewScreen({
    super.key,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final ShoppingList generatedList = IngredientAggregator.fromRecipes(
      appState.selectedMealPlanRecipes(),
      targetServings: appState.targetServings,
    );

    final Set<String> removedGenerated =
        appState.shoppingState.removedGeneratedItemIds.toSet();

    final List<dynamic> visibleRawGeneratedItems = generatedList.items
        .where(
          (dynamic item) => !removedGenerated.contains(_generatedItemId(item)),
        )
        .toList();

    final List<_MergedIngredient> mergedItems =
        _buildMergedIngredients(visibleRawGeneratedItems);

    final List<PurchasableItem> purchasableItems = mergedItems
        .map((_MergedIngredient item) => item.toPurchasableItem())
        .toList();

    final Map<PurchasableCategory, List<PurchasableItem>> grouped =
        _groupByCategory(purchasableItems);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shop-Vorschau'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Vorbereitung für Shop-Integration',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Hier siehst du, welche kaufbaren Artikel aus der Einkaufsliste abgeleitet werden. '
                    'Jetzt bereits mit Coop-orientierten Suchbegriffen.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
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
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        ListTile(
                          title: Text(item.displayName),
                          subtitle: Text(_subtitleFor(item)),
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
                              ElevatedButton.icon(
                                onPressed: () => _openCoopSearch(
                                  item.coopSearchQuery,
                                ),
                                icon: const Icon(Icons.storefront_outlined),
                                label: const Text('Bei Coop suchen'),
                              ),
                              OutlinedButton.icon(
                                onPressed: () => _openGenericWebSearch(
                                  item.shopSearchQuery,
                                ),
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

  static Future<void> _openCoopSearch(String query) async {
    final Uri uri = Uri.https(
      'www.coop.ch',
      '/de/search/',
      <String, String>{'text': query},
    );

    await _launchExternalUri(uri);
  }

  static Future<void> _openGenericWebSearch(String query) async {
    final Uri uri = Uri.https(
      'www.google.com',
      '/search',
      <String, String>{'q': query},
    );

    await _launchExternalUri(uri);
  }

  static Future<void> _launchExternalUri(Uri uri) async {
    final bool ok = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      throw Exception('Konnte URL nicht öffnen: $uri');
    }
  }

  static String _generatedItemId(dynamic item) {
    final dynamic quantity = item.quantity;
    final String quantityPart = quantity == null
        ? 'noqty'
        : '${quantity.value}_${quantity.unit.toString()}';
    return '${item.name}_$quantityPart';
  }

  static String _formatUnitForDisplay(String rawUnit) {
    final String u = rawUnit.toLowerCase().trim();

    switch (u) {
      case 'unit.gram':
      case 'gram':
        return 'gram';
      case 'unit.kilogram':
      case 'kilogram':
        return 'kilogram';
      case 'unit.milliliter':
      case 'milliliter':
        return 'milliliter';
      case 'unit.liter':
      case 'liter':
        return 'liter';
      case 'unit.piece':
      case 'piece':
        return 'piece';
      case 'unit.bunch':
      case 'bunch':
        return 'bunch';
      case 'unit.teaspoon':
      case 'teaspoon':
        return 'teaspoon';
      case 'unit.tablespoon':
      case 'tablespoon':
        return 'tablespoon';
      default:
        return '';
    }
  }

  static List<_MergedIngredient> _buildMergedIngredients(List<dynamic> items) {
    final Map<String, _MergedIngredientBucket> buckets =
        <String, _MergedIngredientBucket>{};

    for (final dynamic item in items) {
      final dynamic quantity = item.quantity;
      final double q =
          quantity == null ? 1.0 : (quantity.value as num).toDouble();
      final String unit = quantity == null
          ? ''
          : _formatUnitForDisplay(quantity.unit.toString());

      final IngredientInterpretation parsed =
          IngredientParser.parse(item.name.toString(), q, unit);

      final String canonicalName =
          IngredientFormatter.canonicalMergeName(parsed.name);

      final String key =
          '$canonicalName|${parsed.unit ?? ''}|${parsed.note ?? ''}';

      buckets.putIfAbsent(
        key,
        () => _MergedIngredientBucket(
          prototype: parsed,
        ),
      );

      buckets[key]!.add(parsed.displayQuantity);
    }

    final List<_MergedIngredient> result = buckets.values.map((
      _MergedIngredientBucket bucket,
    ) {
      return _MergedIngredient(
        name: bucket.prototype.name,
        quantity: bucket.totalQuantity,
        unit: bucket.prototype.unit ?? '',
        note: bucket.prototype.note,
      );
    }).toList();

    result.sort(
      (_MergedIngredient a, _MergedIngredient b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return result;
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

  static String _subtitleFor(PurchasableItem item) {
    final String quantityText = item.quantity == item.quantity.roundToDouble()
        ? item.quantity.toInt().toString()
        : item.quantity.toStringAsFixed(2).replaceAll('.', ',');

    final List<String> lines = <String>[
      item.unit.isEmpty
          ? 'Menge: $quantityText'
          : 'Menge: $quantityText ${item.unit}',
      'Allgemeine Suche: ${item.shopSearchQuery}',
      'Coop-Suche: ${item.coopSearchQuery}',
    ];

    if (item.preferredPackage != null && item.preferredPackage!.isNotEmpty) {
      lines.add('Bevorzugte Packung: ${item.preferredPackage}');
    }

    if (item.purchaseHeuristic != null &&
        item.purchaseHeuristic!.isNotEmpty) {
      lines.add('Strategie: ${item.purchaseHeuristic}');
    }

    if (item.note != null && item.note!.isNotEmpty) {
      lines.add('Hinweis: ${item.note}');
    }

    return lines.join('\n');
  }
}

class _MergedIngredient {
  final String name;
  final double quantity;
  final String unit;
  final String? note;

  const _MergedIngredient({
    required this.name,
    required this.quantity,
    required this.unit,
    required this.note,
  });

  PurchasableItem toPurchasableItem() {
    final String sourceName =
        note == null || note!.isEmpty ? name : '$name $note';

    return PurchasableItemMapper.fromIngredient(
      quantity: quantity,
      unit: unit,
      name: sourceName,
    );
  }
}

class _MergedIngredientBucket {
  final IngredientInterpretation prototype;
  double totalQuantity = 0;

  _MergedIngredientBucket({
    required this.prototype,
  });

  void add(double quantity) {
    totalQuantity += quantity;
  }
}

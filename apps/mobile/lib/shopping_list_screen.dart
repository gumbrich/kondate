import 'package:core/core.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';
import 'ingredient_formatter.dart';

class ShoppingListScreen extends StatefulWidget {
  final KondateAppState appState;

  const ShoppingListScreen({
    super.key,
    required this.appState,
  });

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  late KondateAppState _appState;
  final TextEditingController _manualItemController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _appState = widget.appState;
  }

  String _generatedItemId(dynamic item) {
    final dynamic quantity = item.quantity;
    final String quantityPart = quantity == null
        ? 'noqty'
        : '${quantity.value}_${quantity.unit.toString()}';
    return '${item.name}_$quantityPart';
  }

  String _formatUnitForDisplay(String rawUnit) {
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

  List<_MergedGeneratedItem> _buildMergedItems(List<dynamic> items) {
    final Map<String, _MergeBucket> buckets = <String, _MergeBucket>{};

    for (final dynamic item in items) {
      final dynamic quantity = item.quantity;
      final double q =
          quantity == null ? 1.0 : (quantity.value as num).toDouble();
      final String unit = quantity == null
          ? ''
          : _formatUnitForDisplay(quantity.unit.toString());

      final IngredientInterpretation parsed =
          IngredientParser.parse(item.name.toString(), q, unit);

      final String key =
          '${parsed.name}|${parsed.unit ?? ''}|${parsed.note ?? ''}';

      buckets.putIfAbsent(
        key,
        () => _MergeBucket(
          prototype: parsed,
        ),
      );

      buckets[key]!.add(
        parsed: parsed,
        memberId: _generatedItemId(item),
      );
    }

    final List<_MergedGeneratedItem> result = buckets.values.map((
      _MergeBucket bucket,
    ) {
      return _MergedGeneratedItem(
        text: _formatMerged(bucket.prototype, bucket.totalQuantity),
        memberIds: bucket.memberIds,
      );
    }).toList();

    result.sort(
      (_MergedGeneratedItem a, _MergedGeneratedItem b) =>
          a.text.toLowerCase().compareTo(b.text.toLowerCase()),
    );

    return result;
  }

  String _formatMerged(
    IngredientInterpretation proto,
    double quantity,
  ) {
    return IngredientFormatter.format(
      quantity: quantity,
      unit: proto.unit ?? '',
      name: proto.note == null || proto.note!.isEmpty
          ? proto.name
          : '${proto.name} ${proto.note}',
    );
  }

  Future<void> _setGeneratedChecked(
    List<String> itemIds,
    bool targetChecked,
  ) async {
    setState(() {
      for (final String itemId in itemIds) {
        final bool currentlyChecked =
            _appState.shoppingState.checkedGeneratedItemIds.contains(itemId);
        if (currentlyChecked != targetChecked) {
          _appState = _appState.toggleGeneratedShoppingChecked(itemId);
        }
      }
    });
  }

  Future<void> _hideGeneratedItems(List<String> itemIds) async {
    setState(() {
      for (final String itemId in itemIds) {
        final bool currentlyRemoved =
            _appState.shoppingState.removedGeneratedItemIds.contains(itemId);
        if (!currentlyRemoved) {
          _appState = _appState.toggleGeneratedShoppingRemoved(itemId);
        }
      }
    });
  }

  Future<void> _restoreGeneratedItems(List<String> itemIds) async {
    setState(() {
      for (final String itemId in itemIds) {
        final bool currentlyRemoved =
            _appState.shoppingState.removedGeneratedItemIds.contains(itemId);
        if (currentlyRemoved) {
          _appState = _appState.toggleGeneratedShoppingRemoved(itemId);
        }
      }
    });
  }

  Future<void> _addManualItem() async {
    final String text = _manualItemController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _appState = _appState.addManualShoppingItem(text);
      _manualItemController.clear();
    });
  }

  Future<void> _toggleManualItem(String id) async {
    setState(() {
      _appState = _appState.toggleManualShoppingItem(id);
    });
  }

  Future<void> _removeManualItem(String id) async {
    setState(() {
      _appState = _appState.removeManualShoppingItem(id);
    });
  }

  void _done() {
    Navigator.of(context).pop(_appState);
  }

  Widget _sectionHeader(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 17,
            ),
          ),
          if (subtitle != null) ...<Widget>[
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.black54,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void dispose() {
    _manualItemController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ShoppingList generatedList = IngredientAggregator.fromRecipes(
      _appState.selectedMealPlanRecipes(),
      targetServings: _appState.targetServings,
    );

    final Set<String> checkedGenerated =
        _appState.shoppingState.checkedGeneratedItemIds.toSet();
    final Set<String> removedGenerated =
        _appState.shoppingState.removedGeneratedItemIds.toSet();

    final List<dynamic> visibleRawGeneratedItems = generatedList.items
        .where(
          (dynamic item) => !removedGenerated.contains(_generatedItemId(item)),
        )
        .toList();

    final List<dynamic> hiddenRawGeneratedItems = generatedList.items
        .where(
          (dynamic item) => removedGenerated.contains(_generatedItemId(item)),
        )
        .toList();

    final List<_MergedGeneratedItem> visibleGeneratedItems =
        _buildMergedItems(visibleRawGeneratedItems);
    final List<_MergedGeneratedItem> hiddenGeneratedItems =
        _buildMergedItems(hiddenRawGeneratedItems);

    final int checkedGeneratedCount = visibleGeneratedItems.where(
      (_MergedGeneratedItem item) {
        return item.memberIds.every(checkedGenerated.contains);
      },
    ).length;

    final int checkedManualCount = _appState.shoppingState.manualItems
        .where((ShoppingManualItem item) => item.checked)
        .length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einkaufsliste'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Fertig',
            icon: const Icon(Icons.check),
            onPressed: _done,
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
                  Text(
                    'Für ${_appState.targetServings} Portionen',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Automatisch: ${visibleGeneratedItems.length} Einträge '
                    '($checkedGeneratedCount erledigt)',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    'Manuell: ${_appState.shoppingState.manualItems.length} Einträge '
                    '($checkedManualCount erledigt)',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _sectionHeader(
            'Aus dem Essensplan',
            subtitle: 'Zusammengeführt, wo möglich',
          ),
          if (visibleGeneratedItems.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Keine automatisch erzeugten Einträge.'),
            ),
          ...visibleGeneratedItems.map((_MergedGeneratedItem item) {
            final bool checked = item.memberIds.every(checkedGenerated.contains);

            return Card(
              child: ListTile(
                leading: Checkbox(
                  value: checked,
                  onChanged: (bool? value) {
                    _setGeneratedChecked(item.memberIds, value ?? false);
                  },
                ),
                title: Text(
                  item.text,
                  style: TextStyle(
                    decoration: checked
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: checked ? Colors.black54 : null,
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Ausblenden',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _hideGeneratedItems(item.memberIds),
                ),
              ),
            );
          }),
          if (hiddenGeneratedItems.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _sectionHeader(
              'Ausgeblendete Einträge',
              subtitle: 'Hier kannst du Zutaten wieder einblenden',
            ),
            ...hiddenGeneratedItems.map((_MergedGeneratedItem item) {
              return Card(
                color: Colors.grey.shade50,
                child: ListTile(
                  title: Text(
                    item.text,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  trailing: TextButton.icon(
                    onPressed: () => _restoreGeneratedItems(item.memberIds),
                    icon: const Icon(Icons.undo),
                    label: const Text('Wiederherstellen'),
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 16),
          _sectionHeader(
            'Manuelle Einträge',
            subtitle: 'Dinge, die nicht aus Rezepten kommen',
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _manualItemController,
                  decoration: const InputDecoration(
                    labelText: 'Manuellen Eintrag hinzufügen',
                    hintText: 'z. B. Kaffee, Toilettenpapier',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addManualItem(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _addManualItem,
                child: const Text('Hinzufügen'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_appState.shoppingState.manualItems.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('Noch keine manuellen Einträge.'),
            ),
          ..._appState.shoppingState.manualItems.map((ShoppingManualItem item) {
            return Card(
              child: ListTile(
                leading: Checkbox(
                  value: item.checked,
                  onChanged: (_) => _toggleManualItem(item.id),
                ),
                title: Text(
                  item.name,
                  style: TextStyle(
                    decoration: item.checked
                        ? TextDecoration.lineThrough
                        : TextDecoration.none,
                    color: item.checked ? Colors.black54 : null,
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Löschen',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _removeManualItem(item.id),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _MergedGeneratedItem {
  final String text;
  final List<String> memberIds;

  const _MergedGeneratedItem({
    required this.text,
    required this.memberIds,
  });
}

class _MergeBucket {
  final IngredientInterpretation prototype;
  double totalQuantity = 0;
  final List<String> memberIds = <String>[];

  _MergeBucket({
    required this.prototype,
  });

  void add({
    required IngredientInterpretation parsed,
    required String memberId,
  }) {
    totalQuantity += parsed.displayQuantity;
    memberIds.add(memberId);
  }
}

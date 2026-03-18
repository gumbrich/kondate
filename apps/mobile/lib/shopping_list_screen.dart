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

  String _singleItemText(dynamic item) {
    final dynamic quantity = item.quantity;
    final String rawName = item.name.toString();

    if (quantity == null) {
      return IngredientFormatter.normalizeName(rawName);
    }

    final double value = (quantity.value as num).toDouble();
    final String unit = _formatUnitForDisplay(quantity.unit.toString());

    return IngredientFormatter.format(
      quantity: value,
      unit: unit,
      name: rawName,
    );
  }

  String _mergeKey(dynamic item) {
    final dynamic quantity = item.quantity;
    final String unit = quantity == null
        ? 'none'
        : _formatUnitForDisplay(quantity.unit.toString());
    final String name =
        IngredientFormatter.normalizeName(item.name.toString()).toLowerCase();
    return '$name|$unit';
  }

  List<_MergedGeneratedItem> _buildMergedItems(List<dynamic> items) {
    final Map<String, List<dynamic>> groups = <String, List<dynamic>>{};

    for (final dynamic item in items) {
      final String key = _mergeKey(item);
      groups.putIfAbsent(key, () => <dynamic>[]).add(item);
    }

    final List<_MergedGeneratedItem> merged = <_MergedGeneratedItem>[];

    for (final List<dynamic> groupItems in groups.values) {
      if (groupItems.isEmpty) continue;

      final dynamic first = groupItems.first;
      final List<String> memberIds =
          groupItems.map((dynamic item) => _generatedItemId(item)).toList();

      final bool allHaveQuantity =
          groupItems.every((dynamic item) => item.quantity != null);
      final bool allNumeric = groupItems.every((dynamic item) {
        final dynamic quantity = item.quantity;
        return quantity != null && quantity.value is num;
      });

      if (allHaveQuantity && allNumeric) {
        final dynamic firstQuantity = first.quantity;
        final String unitText =
            _formatUnitForDisplay(firstQuantity.unit.toString());

        final bool sameUnit = groupItems.every((dynamic item) {
          return _formatUnitForDisplay(item.quantity.unit.toString()) ==
              unitText;
        });

        if (sameUnit) {
          double sum = 0;
          for (final dynamic item in groupItems) {
            sum += (item.quantity.value as num).toDouble();
          }

          merged.add(
            _MergedGeneratedItem(
              text: IngredientFormatter.format(
                quantity: sum,
                unit: unitText,
                name: first.name.toString(),
              ),
              memberIds: memberIds,
            ),
          );
          continue;
        }
      }

      for (final dynamic item in groupItems) {
        merged.add(
          _MergedGeneratedItem(
            text: _singleItemText(item),
            memberIds: <String>[_generatedItemId(item)],
          ),
        );
      }
    }

    merged.sort(
      (_MergedGeneratedItem a, _MergedGeneratedItem b) =>
          a.text.toLowerCase().compareTo(b.text.toLowerCase()),
    );

    return merged;
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

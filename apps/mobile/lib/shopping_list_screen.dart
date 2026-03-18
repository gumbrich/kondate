import 'package:core/core.dart';
import 'package:flutter/material.dart';

import 'app_state.dart';

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

  String _singleItemText(dynamic item) {
    final dynamic quantity = item.quantity;
    if (quantity == null) {
      return item.name.toString();
    }

    final String value = quantity.value.toString();
    final String unit = quantity.unit.toString();
    return '$value $unit ${item.name}';
  }

  String _mergeKey(dynamic item) {
    final dynamic quantity = item.quantity;
    final String unit = quantity == null ? 'none' : quantity.unit.toString();
    return '${item.name.toString().trim().toLowerCase()}|$unit';
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
        final String unitText = firstQuantity.unit.toString();

        final bool sameUnit = groupItems.every((dynamic item) {
          return item.quantity.unit.toString() == unitText;
        });

        if (sameUnit) {
          double sum = 0;
          for (final dynamic item in groupItems) {
            sum += (item.quantity.value as num).toDouble();
          }

          merged.add(
            _MergedGeneratedItem(
              text: '${_formatNumber(sum)} $unitText ${first.name}',
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

  String _formatNumber(double value) {
    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(1).replaceAll('.', ',');
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
        title: const Text('Shopping list'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Done',
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
                    'For ${_appState.targetServings} servings',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Generated: ${visibleGeneratedItems.length} items '
                    '($checkedGeneratedCount checked)',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    'Manual: ${_appState.shoppingState.manualItems.length} items '
                    '($checkedManualCount checked)',
                    style: const TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _sectionHeader(
            'Generated from meal plan',
            subtitle: 'Merged where possible',
          ),
          if (visibleGeneratedItems.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('No generated shopping items.'),
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
                  tooltip: 'Hide this item',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _hideGeneratedItems(item.memberIds),
                ),
              ),
            );
          }),
          if (hiddenGeneratedItems.isNotEmpty) ...<Widget>[
            const SizedBox(height: 12),
            _sectionHeader(
              'Hidden generated items',
              subtitle: 'Restore ingredients you want back on the list',
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
                    label: const Text('Restore'),
                  ),
                ),
              );
            }),
          ],
          const SizedBox(height: 16),
          _sectionHeader(
            'Manual items',
            subtitle: 'Things not derived from recipes',
          ),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _manualItemController,
                  decoration: const InputDecoration(
                    labelText: 'Add manual item',
                    hintText: 'e.g. Coffee, toilet paper',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => _addManualItem(),
                ),
              ),
              const SizedBox(width: 12),
              ElevatedButton(
                onPressed: _addManualItem,
                child: const Text('Add'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_appState.shoppingState.manualItems.isEmpty)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('No manual items yet.'),
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
                  tooltip: 'Delete manual item',
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

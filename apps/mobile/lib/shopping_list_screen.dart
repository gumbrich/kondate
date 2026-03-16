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
        : '${quantity.value}_${quantity.unit.name}';
    return '${item.name}_$quantityPart';
  }

  Future<void> _toggleGeneratedChecked(String itemId) async {
    setState(() {
      _appState = _appState.toggleGeneratedShoppingChecked(itemId);
    });
  }

  Future<void> _toggleGeneratedRemoved(String itemId) async {
    setState(() {
      _appState = _appState.toggleGeneratedShoppingRemoved(itemId);
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

    final List<dynamic> visibleGeneratedItems = generatedList.items
        .where((dynamic item) => !removedGenerated.contains(_generatedItemId(item)))
        .toList();

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
          Text(
            'For ${_appState.targetServings} servings',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Generated from meal plan',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (visibleGeneratedItems.isEmpty)
            const Text('No generated shopping items.'),
          ...visibleGeneratedItems.map((dynamic item) {
            final String itemId = _generatedItemId(item);
            final bool checked = checkedGenerated.contains(itemId);

            return Card(
              child: ListTile(
                leading: Checkbox(
                  value: checked,
                  onChanged: (_) => _toggleGeneratedChecked(itemId),
                ),
                title: Text(
                  item.displayText,
                  style: TextStyle(
                    decoration:
                        checked ? TextDecoration.lineThrough : TextDecoration.none,
                  ),
                ),
                trailing: IconButton(
                  tooltip: 'Hide this item',
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _toggleGeneratedRemoved(itemId),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          const Text(
            'Manual items',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _manualItemController,
                  decoration: const InputDecoration(
                    labelText: 'Add manual item',
                    hintText: 'e.g. Coffee, toilet paper',
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
            const Text('No manual items yet.'),
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
                    decoration:
                        item.checked ? TextDecoration.lineThrough : TextDecoration.none,
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

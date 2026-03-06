import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:recipe_parser/recipe_parser.dart';

void main() {
  runApp(const KondateApp());
}

class KondateApp extends StatelessWidget {
  const KondateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: KondateHome());
  }
}

class KondateHome extends StatefulWidget {
  const KondateHome({super.key});

  @override
  State<KondateHome> createState() => _KondateHomeState();
}

class _KondateHomeState extends State<KondateHome> {
  final _urlController = TextEditingController();

  bool _loading = false;
  String? _error;

  final List<Recipe> _recipes = [];
  final double _targetServings = 2.5;

  Future<void> _importAndAdd() async {
    final urlText = _urlController.text.trim();
    if (urlText.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final importer = KondateRecipeImporter();
      final recipe = await importer.importRecipe(
        url: Uri.parse(urlText),
        id: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      setState(() {
        _recipes.add(recipe);
        _urlController.clear();
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _openShoppingList() {
    final list = IngredientAggregator.fromRecipes(
      _recipes,
      targetServings: _targetServings,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ShoppingListScreen(
          targetServings: _targetServings,
          list: list,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canGenerate = _recipes.isNotEmpty && !_loading;

    return Scaffold(
      appBar: AppBar(title: const Text('Kondate – MVP')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _urlController,
              decoration: const InputDecoration(
                labelText: 'Recipe URL (JSON-LD)',
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _loading ? null : _importAndAdd,
                  child: const Text('Import & add'),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: canGenerate ? _openShoppingList : null,
                  child: const Text('Shopping list'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _recipes.length,
                itemBuilder: (_, i) {
                  final r = _recipes[i];
                  return ListTile(
                    title: Text(r.title),
                    subtitle: Text(r.sourceUrl.toString()),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ShoppingListScreen extends StatefulWidget {
  final double targetServings;
  final ShoppingList list;

  const ShoppingListScreen({
    super.key,
    required this.targetServings,
    required this.list,
  });

  @override
  State<ShoppingListScreen> createState() => _ShoppingListScreenState();
}

class _ShoppingListScreenState extends State<ShoppingListScreen> {
  final Set<String> _checked = {};

  String _itemKey(ShoppingListItem item) {
    final q = item.quantity;
    if (q == null) return item.name;
    return "${item.name}_${q.value}_${q.unit.name}";
  }

  String _formatItem(ShoppingListItem item) {
    final q = item.quantity;

    if (q == null) {
      return item.name;
    }

    final unit = UnitFormatDe.short(q.unit);
    final value = q.value.toStringAsFixed(2).replaceAll(RegExp(r'\.?0+$'), '');

    if (unit.isEmpty) {
      return "$value ${item.name}";
    }

    return "$value $unit ${item.name}";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Shopping list (${widget.targetServings})"),
      ),
      body: ListView.builder(
        itemCount: widget.list.items.length,
        itemBuilder: (_, i) {
          final item = widget.list.items[i];
          final key = _itemKey(item);

          final checked = _checked.contains(key);

          return CheckboxListTile(
            value: checked,
            title: Text(
              _formatItem(item),
              style: TextStyle(
                decoration: checked ? TextDecoration.lineThrough : null,
              ),
            ),
            onChanged: (v) {
              setState(() {
                if (v == true) {
                  _checked.add(key);
                } else {
                  _checked.remove(key);
                }
              });
            },
          );
        },
      ),
    );
  }
}

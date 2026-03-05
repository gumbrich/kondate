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

  // In-memory “week”
  final List<Recipe> _recipes = [];

  // Household default
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
    } catch (e, st) {
      setState(() {
        _error = '$e\n\n$st';
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
          recipes: _recipes,
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
            if (_error != null) ...[
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ] else ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Added recipes (${_recipes.length})',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.builder(
                  itemCount: _recipes.length,
                  itemBuilder: (_, i) {
                    final r = _recipes[i];
                    return ListTile(
                      title: Text(r.title),
                      subtitle: Text(
                        'Servings: ${r.defaultServings?.toString() ?? "?"} • ${r.sourceUrl}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: () {
                          setState(() {
                            _recipes.removeAt(i);
                          });
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class ShoppingListScreen extends StatelessWidget {
  final double targetServings;
  final List<Recipe> recipes;
  final ShoppingList list;

  const ShoppingListScreen({
    super.key,
    required this.targetServings,
    required this.recipes,
    required this.list,
  });

  String _formatQty(ShoppingListItem item) {
    final q = item.quantity;
    if (q == null) return item.name;

    // MVP formatting: use German unit short forms where we have them
    final unit = UnitFormatDe.short(q.unit);
    final value = _prettyNumber(q.value);

    if (unit.isEmpty) return '$value ${item.name}';
    return '$value $unit ${item.name}';
  }

  String _prettyNumber(double x) {
    // Keep it simple for MVP: max 2 decimals, trim trailing zeros
    final s = x.toStringAsFixed(2);
    return s.replaceAll(RegExp(r'\.?0+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Shopping list (${targetServings}p)'),
      ),
      body: ListView.builder(
        itemCount: list.items.length,
        itemBuilder: (_, i) {
          final item = list.items[i];
          return ListTile(
            title: Text(_formatQty(item)),
          );
        },
      ),
    );
  }
}

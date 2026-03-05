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
          list: list,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
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
  final ShoppingList list;

  const ShoppingListScreen({
    super.key,
    required this.targetServings,
    required this.list,
  });

  static const List<CategoryDe> _categoryOrder = <CategoryDe>[
    CategoryDe.gemuese,
    CategoryDe.obst,
    CategoryDe.milchprodukte,
    CategoryDe.fleischFisch,
    CategoryDe.tiefkuehl,
    CategoryDe.konserven,
    CategoryDe.trockenwaren,
    CategoryDe.backen,
    CategoryDe.oeleSaucen,
    CategoryDe.gewuerze,
    CategoryDe.getraenke,
    CategoryDe.sonstiges,
  ];

  String _categoryLabel(CategoryDe c) {
    switch (c) {
      case CategoryDe.gemuese:
        return 'Gemüse';
      case CategoryDe.obst:
        return 'Obst';
      case CategoryDe.milchprodukte:
        return 'Milchprodukte';
      case CategoryDe.fleischFisch:
        return 'Fleisch / Fisch';
      case CategoryDe.trockenwaren:
        return 'Trockenwaren';
      case CategoryDe.backen:
        return 'Backen';
      case CategoryDe.gewuerze:
        return 'Gewürze';
      case CategoryDe.oeleSaucen:
        return 'Öle & Saucen';
      case CategoryDe.konserven:
        return 'Konserven';
      case CategoryDe.tiefkuehl:
        return 'Tiefkühl';
      case CategoryDe.getraenke:
        return 'Getränke';
      case CategoryDe.sonstiges:
        return 'Sonstiges';
    }
  }

  String _prettyNumber(double x) {
    final s = x.toStringAsFixed(2);
    return s.replaceAll(RegExp(r'\.?0+$'), '');
  }

  String _formatItem(ShoppingListItem item) {
    final q = item.quantity;
    if (q == null) return item.name;

    final unit = UnitFormatDe.short(q.unit);
    final value = _prettyNumber(q.value);

    if (unit.isEmpty) return '$value ${item.name}';
    return '$value $unit ${item.name}';
  }

  @override
  Widget build(BuildContext context) {
    final Map<CategoryDe, List<ShoppingListItem>> byCat = {};
    for (final it in list.items) {
      (byCat[it.category] ??= <ShoppingListItem>[]).add(it);
    }

    final List<_Row> rows = <_Row>[];
    for (final cat in _categoryOrder) {
      final items = byCat[cat];
      if (items == null || items.isEmpty) continue;

      items.sort((a, b) => a.name.compareTo(b.name));

      rows.add(_Row.header(_categoryLabel(cat)));
      for (final it in items) {
        rows.add(_Row.item(it));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Shopping list (${_prettyNumber(targetServings)}p)'),
      ),
      body: ListView.builder(
        itemCount: rows.length,
        itemBuilder: (_, i) {
          final r = rows[i];
          if (r.isHeader) {
            return Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                r.headerText!,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }

          final item = r.item!;
          return ListTile(
            dense: true,
            title: Text(_formatItem(item)),
          );
        },
      ),
    );
  }
}

class _Row {
  final bool isHeader;
  final String? headerText;
  final ShoppingListItem? item;

  const _Row._({required this.isHeader, this.headerText, this.item});

  factory _Row.header(String text) =>
      _Row._(isHeader: true, headerText: text);

  factory _Row.item(ShoppingListItem item) =>
      _Row._(isHeader: false, item: item);
}

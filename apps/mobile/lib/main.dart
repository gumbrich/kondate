import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:recipe_parser/recipe_parser.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  static const String _prefsKey = 'shopping_checked_keys';

  final Set<String> _checked = {};
  bool _prefsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadChecked();
  }

  Future<void> _loadChecked() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getStringList(_prefsKey) ?? <String>[];

    if (!mounted) return;

    setState(() {
      _checked
        ..clear()
        ..addAll(saved);
      _prefsLoaded = true;
    });
  }

  Future<void> _saveChecked() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_prefsKey, _checked.toList());
  }

  Future<void> _clearChecked() async {
    setState(() {
      _checked.clear();
    });
    await _saveChecked();
  }

  String _itemKey(ShoppingListItem item) {
    final q = item.quantity;
    if (q == null) return '${item.category.name}__${item.name}';
    return '${item.category.name}__${item.name}__${q.value}__${q.unit.name}';
  }

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

    if (q == null) {
      return item.name;
    }

    final unit = UnitFormatDe.short(q.unit);
    final value = _prettyNumber(q.value);

    if (unit.isEmpty) {
      return '$value ${item.name}';
    }

    return '$value $unit ${item.name}';
  }

  @override
  Widget build(BuildContext context) {
    final Map<CategoryDe, List<ShoppingListItem>> byCat = {};
    for (final it in widget.list.items) {
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
        title: Text('Shopping list (${widget.targetServings})'),
        actions: [
          IconButton(
            tooltip: 'Clear checked',
            icon: const Icon(Icons.refresh),
            onPressed: _clearChecked,
          ),
        ],
      ),
      body: !_prefsLoaded
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: rows.length,
              itemBuilder: (_, i) {
                final row = rows[i];

                if (row.isHeader) {
                  return Container(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Text(
                      row.headerText!,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                }

                final item = row.item!;
                final key = _itemKey(item);
                final checked = _checked.contains(key);

                return CheckboxListTile(
                  value: checked,
                  title: Text(
                    _formatItem(item),
                    style: TextStyle(
                      decoration:
                          checked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  onChanged: (v) async {
                    setState(() {
                      if (v == true) {
                        _checked.add(key);
                      } else {
                        _checked.remove(key);
                      }
                    });
                    await _saveChecked();
                  },
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

  const _Row._({
    required this.isHeader,
    this.headerText,
    this.item,
  });

  factory _Row.header(String text) {
    return _Row._(
      isHeader: true,
      headerText: text,
    );
  }

  factory _Row.item(ShoppingListItem item) {
    return _Row._(
      isHeader: false,
      item: item,
    );
  }
}

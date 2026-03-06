import 'dart:convert';

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
  static const String _recipesPrefsKey = 'saved_recipes_v1';

  final TextEditingController _urlController = TextEditingController();

  bool _loading = false;
  bool _recipesLoaded = false;
  String? _error;

  final List<Recipe> _recipes = <Recipe>[];
  final double _targetServings = 2.5;

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Future<void> _loadRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_recipesPrefsKey);

    if (raw == null || raw.isEmpty) {
      if (!mounted) return;
      setState(() {
        _recipesLoaded = true;
      });
      return;
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      final loaded = decoded
          .whereType<Map<String, dynamic>>()
          .map(_recipeFromJson)
          .toList();

      if (!mounted) return;
      setState(() {
        _recipes
          ..clear()
          ..addAll(loaded);
        _recipesLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _recipesLoaded = true;
        _error = 'Could not restore saved recipes.';
      });
    }
  }

  Future<void> _saveRecipes() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = jsonEncode(_recipes.map(_recipeToJson).toList());
    await prefs.setString(_recipesPrefsKey, encoded);
  }

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

      await _saveRecipes();
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

  Future<void> _removeRecipeAt(int index) async {
    setState(() {
      _recipes.removeAt(index);
    });
    await _saveRecipes();
  }

  Future<void> _clearRecipes() async {
    setState(() {
      _recipes.clear();
    });
    await _saveRecipes();
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

  Map<String, dynamic> _recipeToJson(Recipe recipe) {
    return <String, dynamic>{
      'id': recipe.id,
      'title': recipe.title,
      'sourceUrl': recipe.sourceUrl.toString(),
      'defaultServings': recipe.defaultServings,
      'ingredients': recipe.ingredients.map(_ingredientLineToJson).toList(),
    };
  }

  Recipe _recipeFromJson(Map<String, dynamic> json) {
    final ingredientsRaw = json['ingredients'] as List<dynamic>? ?? <dynamic>[];

    return Recipe(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      sourceUrl: Uri.parse(json['sourceUrl'] as String? ?? 'https://example.com'),
      defaultServings: (json['defaultServings'] as num?)?.toDouble(),
      ingredients: ingredientsRaw
          .whereType<Map<String, dynamic>>()
          .map(_ingredientLineFromJson)
          .toList(),
    );
  }

  Map<String, dynamic> _ingredientLineToJson(IngredientLine line) {
    return <String, dynamic>{
      'raw': line.raw,
      'normalizedName': line.normalizedName,
      'quantity': line.quantity == null
          ? null
          : <String, dynamic>{
              'value': line.quantity!.value,
              'unit': line.quantity!.unit.name,
            },
    };
  }

  IngredientLine _ingredientLineFromJson(Map<String, dynamic> json) {
    final q = json['quantity'] as Map<String, dynamic>?;

    return IngredientLine(
      raw: json['raw'] as String? ?? '',
      normalizedName: json['normalizedName'] as String?,
      quantity: q == null
          ? null
          : Quantity(
              (q['value'] as num).toDouble(),
              _unitFromName(q['unit'] as String?),
            ),
    );
  }

  Unit _unitFromName(String? name) {
    return Unit.values.firstWhere(
      (u) => u.name == name,
      orElse: () => Unit.unknown,
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canGenerate = _recipes.isNotEmpty && !_loading;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kondate – MVP'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Clear imported recipes',
            icon: const Icon(Icons.delete_sweep),
            onPressed: _recipes.isEmpty ? null : _clearRecipes,
          ),
        ],
      ),
      body: !_recipesLoaded
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: <Widget>[
                  TextField(
                    controller: _urlController,
                    decoration: const InputDecoration(
                      labelText: 'Recipe URL (JSON-LD)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: <Widget>[
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
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Saved recipes (${_recipes.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: _recipes.length,
                      itemBuilder: (_, int i) {
                        final Recipe r = _recipes[i];
                        return ListTile(
                          title: Text(r.title),
                          subtitle: Text(
                            r.sourceUrl.toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () => _removeRecipeAt(i),
                          ),
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

  final Set<String> _checked = <String>{};
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
    final Quantity? q = item.quantity;
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
    final String s = x.toStringAsFixed(2);
    return s.replaceAll(RegExp(r'\.?0+$'), '');
  }

  String _formatItem(ShoppingListItem item) {
    final Quantity? q = item.quantity;

    if (q == null) {
      return item.name;
    }

    final String unit = UnitFormatDe.short(q.unit);
    final String value = _prettyNumber(q.value);

    if (unit.isEmpty) {
      return '$value ${item.name}';
    }

    return '$value $unit ${item.name}';
  }

  @override
  Widget build(BuildContext context) {
    final Map<CategoryDe, List<ShoppingListItem>> byCat =
        <CategoryDe, List<ShoppingListItem>>{};
    for (final ShoppingListItem it in widget.list.items) {
      (byCat[it.category] ??= <ShoppingListItem>[]).add(it);
    }

    final List<_Row> rows = <_Row>[];
    for (final CategoryDe cat in _categoryOrder) {
      final List<ShoppingListItem>? items = byCat[cat];
      if (items == null || items.isEmpty) continue;

      items.sort((ShoppingListItem a, ShoppingListItem b) {
        return a.name.compareTo(b.name);
      });

      rows.add(_Row.header(_categoryLabel(cat)));
      for (final ShoppingListItem it in items) {
        rows.add(_Row.item(it));
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Shopping list (${widget.targetServings})'),
        actions: <Widget>[
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
              itemBuilder: (_, int i) {
                final _Row row = rows[i];

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

                final ShoppingListItem item = row.item!;
                final String key = _itemKey(item);
                final bool checked = _checked.contains(key);

                return CheckboxListTile(
                  value: checked,
                  title: Text(
                    _formatItem(item),
                    style: TextStyle(
                      decoration:
                          checked ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  onChanged: (bool? v) async {
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

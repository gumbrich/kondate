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
  static const String _servingsPrefsKey = 'target_servings_v1';
  static const String _mealPlanPrefsKey = 'meal_plan_v1';

  final TextEditingController _urlController = TextEditingController();

  bool _loading = false;
  bool _dataLoaded = false;
  String? _error;

  final List<Recipe> _recipes = <Recipe>[];
  double _targetServings = 2.5;

  MealPlanWeek _mealPlan = MealPlanWeek(
    entries: const <MealPlanEntry>[
      MealPlanEntry(weekday: WeekdayDe.montag),
      MealPlanEntry(weekday: WeekdayDe.dienstag),
      MealPlanEntry(weekday: WeekdayDe.mittwoch),
      MealPlanEntry(weekday: WeekdayDe.donnerstag),
      MealPlanEntry(weekday: WeekdayDe.freitag),
      MealPlanEntry(weekday: WeekdayDe.samstag),
      MealPlanEntry(weekday: WeekdayDe.sonntag),
    ],
  );

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    final double? savedServings = prefs.getDouble(_servingsPrefsKey);
    if (savedServings != null && savedServings > 0) {
      _targetServings = savedServings;
    }

    final String? recipesRaw = prefs.getString(_recipesPrefsKey);
    if (recipesRaw != null && recipesRaw.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(recipesRaw) as List<dynamic>;
        final List<Recipe> loaded = decoded
            .whereType<Map<String, dynamic>>()
            .map(_recipeFromJson)
            .toList();

        _recipes
          ..clear()
          ..addAll(loaded);
      } catch (_) {
        _error = 'Could not restore saved recipes.';
      }
    }

    final String? mealPlanRaw = prefs.getString(_mealPlanPrefsKey);
    if (mealPlanRaw != null && mealPlanRaw.isNotEmpty) {
      try {
        final List<dynamic> decoded = jsonDecode(mealPlanRaw) as List<dynamic>;
        final List<MealPlanEntry> entries = decoded
            .whereType<Map<String, dynamic>>()
            .map(_mealPlanEntryFromJson)
            .toList();

        _mealPlan = MealPlanWeek(entries: entries);
      } catch (_) {
        _error = 'Could not restore meal plan.';
      }
    }

    if (!mounted) return;
    setState(() {
      _dataLoaded = true;
    });
  }

  Future<void> _saveRecipes() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(_recipes.map(_recipeToJson).toList());
    await prefs.setString(_recipesPrefsKey, encoded);
  }

  Future<void> _saveServings() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_servingsPrefsKey, _targetServings);
  }

  Future<void> _saveMealPlan() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String encoded =
        jsonEncode(_mealPlan.entries.map(_mealPlanEntryToJson).toList());
    await prefs.setString(_mealPlanPrefsKey, encoded);
  }

  Future<void> _incrementServings() async {
    setState(() {
      _targetServings += 0.5;
    });
    await _saveServings();
  }

  Future<void> _decrementServings() async {
    if (_targetServings <= 0.5) return;

    setState(() {
      _targetServings -= 0.5;
    });
    await _saveServings();
  }

  Future<void> _importAndAdd() async {
    final String urlText = _urlController.text.trim();
    if (urlText.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final KondateRecipeImporter importer = KondateRecipeImporter();
      final Recipe recipe = await importer.importRecipe(
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

  Future<void> _openManualRecipeScreen() async {
    final Recipe? recipe = await Navigator.of(context).push<Recipe>(
      MaterialPageRoute(
        builder: (_) => const ManualRecipeScreen(),
      ),
    );

    if (recipe == null) return;

    setState(() {
      _recipes.add(recipe);
      _error = null;
    });

    await _saveRecipes();
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

  Future<void> _assignRecipeToWeekday(WeekdayDe weekday) async {
    if (_recipes.isEmpty) {
      setState(() {
        _error = 'Please import or add a recipe first.';
      });
      return;
    }

    final String? recipeId = await showModalBottomSheet<String>(
      context: context,
      builder: (_) {
        return SafeArea(
          child: ListView(
            children: _recipes.map((Recipe recipe) {
              return ListTile(
                title: Text(recipe.title),
                subtitle: Text(
                  recipe.sourceUrl.toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => Navigator.of(context).pop(recipe.id),
              );
            }).toList(),
          ),
        );
      },
    );

    if (recipeId == null) return;

    final MealPlanEntry current =
        _mealPlan.entryFor(weekday) ?? MealPlanEntry(weekday: weekday);

    setState(() {
      _mealPlan = _mealPlan.upsert(
        current.copyWith(recipeId: recipeId),
      );
    });

    await _saveMealPlan();
  }

  Future<void> _clearWeekday(WeekdayDe weekday) async {
    final MealPlanEntry current =
        _mealPlan.entryFor(weekday) ?? MealPlanEntry(weekday: weekday);

    setState(() {
      _mealPlan = _mealPlan.upsert(
        current.copyWith(recipeId: null),
      );
    });

    await _saveMealPlan();
  }

  void _openShoppingList() {
    final List<Recipe> selectedRecipes = _selectedMealPlanRecipes();

    final ShoppingList list = IngredientAggregator.fromRecipes(
      selectedRecipes,
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

  List<Recipe> _selectedMealPlanRecipes() {
    final List<Recipe> result = <Recipe>[];

    for (final MealPlanEntry entry in _mealPlan.entries) {
      final String? recipeId = entry.recipeId;
      if (recipeId == null) continue;

      final Recipe? recipe = _findRecipeById(recipeId);
      if (recipe != null) {
        result.add(recipe);
      }
    }

    return result;
  }

  Recipe? _findRecipeById(String id) {
    for (final Recipe recipe in _recipes) {
      if (recipe.id == id) return recipe;
    }
    return null;
  }

  String _weekdayLabel(WeekdayDe weekday) {
    switch (weekday) {
      case WeekdayDe.montag:
        return 'Montag';
      case WeekdayDe.dienstag:
        return 'Dienstag';
      case WeekdayDe.mittwoch:
        return 'Mittwoch';
      case WeekdayDe.donnerstag:
        return 'Donnerstag';
      case WeekdayDe.freitag:
        return 'Freitag';
      case WeekdayDe.samstag:
        return 'Samstag';
      case WeekdayDe.sonntag:
        return 'Sonntag';
    }
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
    final List<dynamic> ingredientsRaw =
        json['ingredients'] as List<dynamic>? ?? <dynamic>[];

    return Recipe(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      sourceUrl: Uri.parse(
        json['sourceUrl'] as String? ?? 'https://example.com',
      ),
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
    final Map<String, dynamic>? q = json['quantity'] as Map<String, dynamic>?;

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

  Map<String, dynamic> _mealPlanEntryToJson(MealPlanEntry entry) {
    return <String, dynamic>{
      'weekday': entry.weekday.name,
      'dishIdea': entry.dishIdea,
      'recipeId': entry.recipeId,
    };
  }

  MealPlanEntry _mealPlanEntryFromJson(Map<String, dynamic> json) {
    return MealPlanEntry(
      weekday: WeekdayDe.values.firstWhere(
        (WeekdayDe d) => d.name == json['weekday'],
        orElse: () => WeekdayDe.montag,
      ),
      dishIdea: json['dishIdea'] as String?,
      recipeId: json['recipeId'] as String?,
    );
  }

  Unit _unitFromName(String? name) {
    return Unit.values.firstWhere(
      (Unit u) => u.name == name,
      orElse: () => Unit.unknown,
    );
  }

  String _prettyNumber(double x) {
    final String s = x.toStringAsFixed(2);
    return s.replaceAll(RegExp(r'\.?0+$'), '');
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canGenerate =
        _selectedMealPlanRecipes().isNotEmpty && !_loading;

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
      body: !_dataLoaded
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
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: <Widget>[
                      ElevatedButton(
                        onPressed: _loading ? null : _importAndAdd,
                        child: const Text('Import & add'),
                      ),
                      ElevatedButton(
                        onPressed: _loading ? null : _openManualRecipeScreen,
                        child: const Text('Manual recipe'),
                      ),
                      ElevatedButton(
                        onPressed: canGenerate ? _openShoppingList : null,
                        child: const Text('Shopping list'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      const Text(
                        'Household servings:',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(width: 12),
                      IconButton(
                        onPressed: _decrementServings,
                        icon: const Icon(Icons.remove_circle_outline),
                      ),
                      Text(
                        _prettyNumber(_targetServings),
                        style: const TextStyle(fontSize: 18),
                      ),
                      IconButton(
                        onPressed: _incrementServings,
                        icon: const Icon(Icons.add_circle_outline),
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
                      'Weekly plan',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      children: WeekdayDe.values.map((WeekdayDe weekday) {
                        final MealPlanEntry entry =
                            _mealPlan.entryFor(weekday) ??
                                MealPlanEntry(weekday: weekday);

                        final Recipe? recipe = entry.recipeId == null
                            ? null
                            : _findRecipeById(entry.recipeId!);

                        return Card(
                          child: ListTile(
                            title: Text(_weekdayLabel(weekday)),
                            subtitle: Text(
                              recipe?.title ?? 'No recipe selected',
                            ),
                            onTap: () => _assignRecipeToWeekday(weekday),
                            trailing: recipe == null
                                ? const Icon(Icons.add)
                                : IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () => _clearWeekday(weekday),
                                  ),
                          ),
                        );
                      }).toList(),
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
                  SizedBox(
                    height: 180,
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

class ManualRecipeScreen extends StatefulWidget {
  const ManualRecipeScreen({super.key});

  @override
  State<ManualRecipeScreen> createState() => _ManualRecipeScreenState();
}

class _ManualRecipeScreenState extends State<ManualRecipeScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _servingsController =
      TextEditingController(text: '2.5');
  final TextEditingController _ingredientsController = TextEditingController();

  String? _error;

  Recipe _buildRecipe() {
    final String title = _titleController.text.trim();
    final String ingredientsText = _ingredientsController.text.trim();
    final double? servings =
        double.tryParse(_servingsController.text.trim().replaceAll(',', '.'));

    if (title.isEmpty) {
      throw Exception('Please enter a recipe title.');
    }
    if (ingredientsText.isEmpty) {
      throw Exception('Please enter at least one ingredient line.');
    }

    final List<String> lines = ingredientsText
        .split('\n')
        .map((String s) => s.trim())
        .where((String s) => s.isNotEmpty)
        .toList();

    final List<IngredientLine> ingredients = lines.map((String raw) {
      final Quantity? q = QuantityParserDe.parseLeadingQuantity(raw);
      return IngredientLine(
        raw: raw,
        quantity: q,
        normalizedName: null,
      );
    }).toList();

    return Recipe(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      sourceUrl: Uri.parse('manual://recipe/$title'),
      defaultServings: servings,
      ingredients: ingredients,
    );
  }

  void _save() {
    try {
      final Recipe recipe = _buildRecipe();
      Navigator.of(context).pop(recipe);
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _servingsController.dispose();
    _ingredientsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manual recipe'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _titleController,
              decoration: const InputDecoration(
                labelText: 'Recipe title',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _servingsController,
              decoration: const InputDecoration(
                labelText: 'Recipe servings',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TextField(
                controller: _ingredientsController,
                decoration: const InputDecoration(
                  labelText: 'Ingredients (one per line)',
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(),
                ),
                maxLines: null,
                expands: true,
              ),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _save,
                    child: const Text('Save'),
                  ),
                ),
              ],
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
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final List<String> saved = prefs.getStringList(_prefsKey) ?? <String>[];

    if (!mounted) return;

    setState(() {
      _checked
        ..clear()
        ..addAll(saved);
      _prefsLoaded = true;
    });
  }

  Future<void> _saveChecked() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
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

  String _capitalizeGermanNoun(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  String _formatItem(ShoppingListItem item) {
    final Quantity? q = item.quantity;
    final String displayName = _capitalizeGermanNoun(item.name);

    if (q == null) {
      return displayName;
    }

    final String unit = UnitFormatDe.short(q.unit);
    final String value = _prettyNumber(q.value);

    if (unit.isEmpty) {
      return '$value $displayName';
    }

    return '$value $unit $displayName';
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
        title: Text('Shopping list (${_prettyNumber(widget.targetServings)})'),
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

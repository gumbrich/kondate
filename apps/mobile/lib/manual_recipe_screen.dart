import 'package:core/core.dart';
import 'package:flutter/material.dart';

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

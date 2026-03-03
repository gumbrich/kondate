import 'package:flutter/material.dart';
import 'package:recipe_parser/recipe_parser.dart';

void main() {
  runApp(const KondateApp());
}

class KondateApp extends StatelessWidget {
  const KondateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      home: ImportRecipeScreen(),
    );
  }
}

class ImportRecipeScreen extends StatefulWidget {
  const ImportRecipeScreen({super.key});

  @override
  State<ImportRecipeScreen> createState() => _ImportRecipeScreenState();
}

class _ImportRecipeScreenState extends State<ImportRecipeScreen> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;
  String? _title;
  List<String> _ingredients = [];

  Future<void> _import() async {
    final urlText = _controller.text.trim();
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
        _title = recipe.title;
        _ingredients = recipe.ingredients.map((e) {
          final q = e.quantity;
          if (q == null) return e.raw;
          return "${q.value} ${q.unit.name} — ${e.raw}";
        }).toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Kondate – Import Recipe")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: "Recipe URL",
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _import,
              child: const Text("Import"),
            ),
            const SizedBox(height: 20),
            if (_loading) const CircularProgressIndicator(),
            if (_error != null)
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            if (_title != null) ...[
              Text(
                _title!,
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView(
                  children:
                      _ingredients.map((e) => ListTile(title: Text(e))).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

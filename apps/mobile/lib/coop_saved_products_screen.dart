import 'package:flutter/material.dart';

import 'coop_product_preferences.dart';
import 'coop_saved_product.dart';
import 'coop_saved_products_store.dart';

class CoopSavedProductsScreen extends StatefulWidget {
  const CoopSavedProductsScreen({super.key});

  @override
  State<CoopSavedProductsScreen> createState() =>
      _CoopSavedProductsScreenState();
}

class _CoopSavedProductsScreenState extends State<CoopSavedProductsScreen> {
  final CoopSavedProductsStore _store = CoopSavedProductsStore();

  List<String> _keys = [];
  bool _loading = true;
  bool _saving = false;
  String? _message;

  late final Map<String, TextEditingController> _labelControllers;
  late final Map<String, TextEditingController> _urlControllers;

  @override
  void initState() {
    super.initState();
    _labelControllers = <String, TextEditingController>{};
    _urlControllers = <String, TextEditingController>{};
    _load();
  }

  Future<void> _load() async {
    final Map<String, CoopSavedProduct> saved = await _store
        .loadSavedProducts();

    _keys = {
      ...CoopProductPreferences.defaults.map((p) => p.canonicalKey),
      ...saved.keys,
    }.toList()..sort();
    for (final key in _keys) {
      final CoopSavedProduct? existing = saved[key];

      _labelControllers[key] = TextEditingController(
        text: existing?.productLabel ?? '',
      );

      _urlControllers[key] = TextEditingController(
        text: existing?.productUrl ?? '',
      );
    }

    if (!mounted) return;
    setState(() {
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });

    final Map<String, CoopSavedProduct> products = <String, CoopSavedProduct>{};

    for (final key in _keys) {
      final String label = _labelControllers[key]!.text.trim();
      final String url = _urlControllers[key]!.text.trim();

      if (label.isNotEmpty && url.isNotEmpty) {
        products[key] = CoopSavedProduct(
          canonicalKey: key,
          productLabel: label,
          productUrl: url,
        );
      }
    }

    await _store.saveSavedProducts(products);

    if (!mounted) return;
    setState(() {
      _saving = false;
      _message = 'Gespeichert';
    });
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _labelControllers.values) {
      controller.dispose();
    }
    for (final TextEditingController controller in _urlControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gespeicherte Coop-Produkte'),
        actions: <Widget>[
          IconButton(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            tooltip: 'Speichern',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          const Card(
            child: Padding(
              padding: EdgeInsets.all(14),
              child: Text(
                'Hier kannst du pro Produkttyp ein konkretes Coop-Standardprodukt '
                'mit Label und Produktlink speichern. Das ist die Grundlage für '
                'spätere direkte Produktaufrufe und Automatisierung.',
              ),
            ),
          ),
          if (_message != null) ...<Widget>[
            const SizedBox(height: 8),
            Text(
              _message!,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
          const SizedBox(height: 8),
          ..._keys.map((key) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      key,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _labelControllers[key],
                      decoration: const InputDecoration(
                        labelText: 'Produktname bei Coop',
                        hintText: 'z. B. Coop Naturaplan Milch UHT 1 l',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _urlControllers[key],
                      decoration: const InputDecoration(
                        labelText: 'Produktlink',
                        hintText: 'https://www.coop.ch/...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import 'coop_product_preferences.dart';
import 'coop_user_preferences.dart';
import 'coop_user_preferences_store.dart';

class CoopPreferencesScreen extends StatefulWidget {
  const CoopPreferencesScreen({super.key});

  @override
  State<CoopPreferencesScreen> createState() => _CoopPreferencesScreenState();
}

class _CoopPreferencesScreenState extends State<CoopPreferencesScreen> {
  final CoopUserPreferencesStore _store = CoopUserPreferencesStore();

  bool _loading = true;
  bool _saving = false;
  String? _message;

  late final Map<String, TextEditingController> _searchControllers;
  late final Map<String, TextEditingController> _labelControllers;

  @override
  void initState() {
    super.initState();
    _searchControllers = <String, TextEditingController>{};
    _labelControllers = <String, TextEditingController>{};
    _load();
  }

  Future<void> _load() async {
    final Map<String, CoopUserPreferenceOverride> overrides =
        await _store.loadOverrides();

    for (final CoopProductPreference preference in CoopProductPreferences.defaults) {
      final CoopUserPreferenceOverride? override =
          overrides[preference.canonicalKey];

      _searchControllers[preference.canonicalKey] = TextEditingController(
        text: override?.preferredSearchQuery ?? preference.preferredSearchQuery,
      );

      _labelControllers[preference.canonicalKey] = TextEditingController(
        text:
            override?.preferredProductLabel ?? preference.preferredProductLabel,
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

    final Map<String, CoopUserPreferenceOverride> overrides =
        <String, CoopUserPreferenceOverride>{};

    for (final CoopProductPreference preference in CoopProductPreferences.defaults) {
      final String search =
          _searchControllers[preference.canonicalKey]!.text.trim();
      final String label =
          _labelControllers[preference.canonicalKey]!.text.trim();

      overrides[preference.canonicalKey] = CoopUserPreferenceOverride(
        canonicalKey: preference.canonicalKey,
        preferredSearchQuery: search,
        preferredProductLabel: label,
      );
    }

    await _store.saveOverrides(overrides);

    if (!mounted) return;
    setState(() {
      _saving = false;
      _message = 'Gespeichert';
    });
  }

  @override
  void dispose() {
    for (final TextEditingController controller in _searchControllers.values) {
      controller.dispose();
    }
    for (final TextEditingController controller in _labelControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coop-Präferenzen'),
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
                'Hier kannst du für bekannte Produkttypen deine bevorzugten Coop-Suchbegriffe '
                'und Produktprofile lokal auf deinem Gerät überschreiben.',
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
          ...CoopProductPreferences.defaults.map((CoopProductPreference pref) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      pref.canonicalKey,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchControllers[pref.canonicalKey],
                      decoration: const InputDecoration(
                        labelText: 'Bevorzugte Coop-Suche',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _labelControllers[pref.canonicalKey],
                      decoration: const InputDecoration(
                        labelText: 'Bevorzugtes Produktprofil',
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

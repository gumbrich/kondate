import 'package:flutter/material.dart';

class TrustedSitesResult {
  final List<String> sites;
  final int topN;

  const TrustedSitesResult({
    required this.sites,
    required this.topN,
  });
}

class TrustedSitesScreen extends StatefulWidget {
  final List<String> initialSites;
  final int initialTopN;

  const TrustedSitesScreen({
    super.key,
    required this.initialSites,
    required this.initialTopN,
  });

  @override
  State<TrustedSitesScreen> createState() => _TrustedSitesScreenState();
}

class _TrustedSitesScreenState extends State<TrustedSitesScreen> {
  late final TextEditingController _newSiteController;
  late List<String> _sites;
  late int _topN;
  String? _error;

  @override
  void initState() {
    super.initState();
    _newSiteController = TextEditingController();
    _sites = List<String>.from(widget.initialSites);
    _topN = widget.initialTopN;
  }

  void _addSite() {
    final String raw = _newSiteController.text.trim().toLowerCase();
    if (raw.isEmpty) return;

    final String site = raw
        .replaceAll('https://', '')
        .replaceAll('http://', '')
        .replaceAll('/', '');

    if (site.isEmpty || !site.contains('.')) {
      setState(() {
        _error = 'Please enter a valid domain like chefkoch.de';
      });
      return;
    }

    if (_sites.contains(site)) {
      setState(() {
        _error = 'That site is already in the list.';
      });
      return;
    }

    setState(() {
      _sites.add(site);
      _sites.sort();
      _newSiteController.clear();
      _error = null;
    });
  }

  void _removeSite(String site) {
    setState(() {
      _sites.remove(site);
      if (_topN > _sites.length && _sites.isNotEmpty) {
        _topN = _sites.length;
      }
      if (_sites.isEmpty) {
        _topN = 1;
      }
    });
  }

  void _incrementTopN() {
    if (_topN >= _sites.length) return;
    setState(() {
      _topN += 1;
    });
  }

  void _decrementTopN() {
    if (_topN <= 1) return;
    setState(() {
      _topN -= 1;
    });
  }

  @override
  void dispose() {
    _newSiteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final int maxUsableTopN = _sites.isEmpty ? 1 : _sites.length;
    if (_topN > maxUsableTopN) {
      _topN = maxUsableTopN;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Trusted sites'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            TextField(
              controller: _newSiteController,
              decoration: const InputDecoration(
                labelText: 'Add website domain',
                hintText: 'e.g. chefkoch.de',
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: ElevatedButton(
                onPressed: _addSite,
                child: const Text('Add site'),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                const Text(
                  'Top suggestions:',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: _decrementTopN,
                  icon: const Icon(Icons.remove_circle_outline),
                ),
                Text(
                  '$_topN',
                  style: const TextStyle(fontSize: 18),
                ),
                IconButton(
                  onPressed: _incrementTopN,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _sites.length,
                itemBuilder: (_, int i) {
                  final String site = _sites[i];
                  return ListTile(
                    title: Text(site),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => _removeSite(site),
                    ),
                  );
                },
              ),
            ),
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
                    onPressed: () {
                      Navigator.of(context).pop(
                        TrustedSitesResult(
                          sites: _sites,
                          topN: _topN,
                        ),
                      );
                    },
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

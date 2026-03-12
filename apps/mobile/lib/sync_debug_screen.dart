import 'package:flutter/material.dart';

import 'household_api_models.dart';
import 'household_sync_provider.dart';

class SyncDebugScreen extends StatefulWidget {
  final HouseholdSyncProvider syncProvider;

  const SyncDebugScreen({
    super.key,
    required this.syncProvider,
  });

  @override
  State<SyncDebugScreen> createState() => _SyncDebugScreenState();
}

class _SyncDebugScreenState extends State<SyncDebugScreen> {
  bool _loading = false;
  String? _error;
  HouseholdSyncSnapshotDto? _snapshot;

  Future<void> _loadSnapshot() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final HouseholdSyncSnapshotDto snapshot =
          await widget.syncProvider.fetchSnapshot(
        householdId: 'demo-household',
      );

      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    }
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _loadSnapshot();
  }

  @override
  Widget build(BuildContext context) {
    final HouseholdSyncSnapshotDto? snapshot = _snapshot;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sync debug'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Reload snapshot',
            icon: const Icon(Icons.refresh),
            onPressed: _loading ? null : _loadSnapshot,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading && snapshot == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: <Widget>[
                  if (_loading) const LinearProgressIndicator(),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  if (snapshot != null) ...<Widget>[
                    _sectionTitle('Household'),
                    Card(
                      child: ListTile(
                        title: Text(snapshot.household.name),
                        subtitle: Text(
                          'ID: ${snapshot.household.householdId}',
                        ),
                      ),
                    ),
                    _sectionTitle('Members'),
                    ...snapshot.household.members.map((HouseholdMemberDto m) {
                      return Card(
                        child: ListTile(
                          title: Text(m.displayName),
                          subtitle: Text(m.userId),
                        ),
                      );
                    }),
                    _sectionTitle('Trusted sites'),
                    Card(
                      child: ListTile(
                        title: Text(
                          snapshot.trustedSites.sites.join(', '),
                        ),
                        subtitle: Text(
                          'Top N: ${snapshot.trustedSites.topN}',
                        ),
                      ),
                    ),
                    _sectionTitle('Meal plan entries'),
                    ...snapshot.mealPlanEntries.map((MealPlanEntryDto e) {
                      return Card(
                        child: ListTile(
                          title: Text(e.weekday),
                          subtitle: Text(
                            '${e.dishIdea ?? '-'} • recipeId: ${e.recipeId ?? '-'}',
                          ),
                        ),
                      );
                    }),
                    _sectionTitle('Shopping item states'),
                    ...snapshot.shoppingItemStates.map((ShoppingItemStateDto s) {
                      return Card(
                        child: ListTile(
                          title: Text(s.itemKey),
                          subtitle: Text(
                            s.checked ? 'checked' : 'not checked',
                          ),
                        ),
                      );
                    }),
                  ],
                ],
              ),
      ),
    );
  }
}

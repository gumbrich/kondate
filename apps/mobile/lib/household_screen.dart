import 'package:flutter/material.dart';

import 'household_api.dart';

class HouseholdScreen extends StatefulWidget {
  const HouseholdScreen({super.key});

  @override
  State<HouseholdScreen> createState() => _HouseholdScreenState();
}

class _HouseholdScreenState extends State<HouseholdScreen> {
  final HouseholdApi _api = HouseholdApi();
  final TextEditingController _joinCodeController = TextEditingController();

  String? _error;
  bool _loading = false;

  Future<void> _createHousehold() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final HouseholdInfo info = await _api.createHousehold();
      if (!mounted) return;
      Navigator.of(context).pop(info);
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

  Future<void> _joinHousehold() async {
    final String code = _joinCodeController.text.trim();
    if (code.isEmpty) {
      setState(() {
        _error = 'Please enter a join code.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final HouseholdInfo info = await _api.joinHousehold(code);
      if (!mounted) return;
      Navigator.of(context).pop(info);
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
  void dispose() {
    _joinCodeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Household'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: <Widget>[
            ElevatedButton(
              onPressed: _loading ? null : _createHousehold,
              child: const Text('Create household'),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _joinCodeController,
              decoration: const InputDecoration(
                labelText: 'Join code',
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : _joinHousehold,
              child: const Text('Join household'),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                _error!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

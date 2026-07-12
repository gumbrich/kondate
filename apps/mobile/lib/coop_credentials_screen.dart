import 'package:flutter/material.dart';

import 'coop_credentials_store.dart';

class CoopCredentialsScreen extends StatefulWidget {
  const CoopCredentialsScreen({super.key});

  @override
  State<CoopCredentialsScreen> createState() => _CoopCredentialsScreenState();
}

class _CoopCredentialsScreenState extends State<CoopCredentialsScreen> {
  final CoopCredentialsStore _store = CoopCredentialsStore();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  bool _obscurePassword = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    String? message;

    try {
      final CoopCredentials credentials = await _store.load();
      _emailController.text = credentials.email;
      _passwordController.text = credentials.password;
    } catch (error) {
      message = 'Fehler beim Laden der Zugangsdaten: $error';
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = message;
        });
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });

    String? message;

    try {
      await _store.save(
        email: _emailController.text,
        password: _passwordController.text,
      );
      message = 'Gespeichert';
    } catch (error) {
      message = 'Fehler beim Speichern der Zugangsdaten: $error';
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _message = message;
        });
      }
    }
  }

  Future<void> _clear() async {
    setState(() {
      _saving = true;
      _message = null;
    });

    String? message;

    try {
      await _store.clear();
      _emailController.clear();
      _passwordController.clear();
      message = 'Gelöscht';
    } catch (error) {
      message = 'Fehler beim Löschen der Zugangsdaten: $error';
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _message = message;
        });
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coop-Zugangsdaten'),
        actions: <Widget>[
          IconButton(
            onPressed: _saving ? null : _save,
            tooltip: 'Speichern',
            icon: const Icon(Icons.save_outlined),
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
                'Diese Zugangsdaten werden sicher auf deinem Gerät gespeichert '
                'und nur zum Vorbefüllen des Coop-Logins in der In-App-WebView verwendet.',
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
          const SizedBox(height: 12),
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const <String>[AutofillHints.username],
            decoration: const InputDecoration(
              labelText: 'E-Mail',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            autofillHints: const <String>[AutofillHints.password],
            decoration: InputDecoration(
              labelText: 'Passwort',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                onPressed: () {
                  setState(() {
                    _obscurePassword = !_obscurePassword;
                  });
                },
                icon: Icon(
                  _obscurePassword ? Icons.visibility : Icons.visibility_off,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save_outlined),
            label: const Text('Speichern'),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _saving ? null : _clear,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Zugangsdaten löschen'),
          ),
        ],
      ),
    );
  }
}

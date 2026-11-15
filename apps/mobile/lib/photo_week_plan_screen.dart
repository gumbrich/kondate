import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'photo_week_plan.dart';
import 'meal_spelling.dart';
import 'week_plan_photo_source.dart';

typedef PhotoRecognizer = Future<PhotoWeekDraft> Function(Uint8List photo);

class PhotoWeekPlanScreen extends StatefulWidget {
  const PhotoWeekPlanScreen({
    super.key,
    required this.mealPlan,
    required this.recipes,
    this.initialPhoto,
    this.photoSource,
    this.recognize,
  });
  final MealPlanWeek mealPlan;
  final List<Recipe> recipes;
  final Uint8List? initialPhoto;
  final WeekPlanPhotoSource? photoSource;
  final PhotoRecognizer? recognize;

  @override
  State<PhotoWeekPlanScreen> createState() => _PhotoWeekPlanScreenState();
}

class _PhotoWeekPlanScreenState extends State<PhotoWeekPlanScreen> {
  late final _source = widget.photoSource ?? WeekPlanPhotoSource();
  final _controllers = {
    for (final day in WeekdayDe.values) day: TextEditingController(),
  };
  final _selected = <WeekdayDe>{};
  final _drafts = <WeekdayDe, PhotoMealDraft>{};
  Uint8List? _photo;
  bool _busy = false;
  String? _error;
  String _notes = '';
  String _recognizedText = '';

  @override
  void initState() {
    super.initState();
    _photo = widget.initialPhoto;
  }

  @override
  void dispose() {
    _source.cancel();
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String _existing(WeekdayDe day) {
    final entry = widget.mealPlan.entryFor(day);
    final parts = <String>[];
    if (entry?.dishIdea?.trim().isNotEmpty ?? false) {
      parts.add(entry!.dishIdea!.trim());
    }
    if (entry?.recipeId != null) {
      final recipes = widget.recipes.where((r) => r.id == entry!.recipeId);
      parts.add(recipes.isEmpty ? 'Verknüpftes Rezept' : recipes.first.title);
    }
    return parts.join(' · ');
  }

  Future<bool> _confirmDiscard() async {
    if (!_controllers.values.any((c) => c.text.isNotEmpty)) return true;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Entwurf ersetzen?'),
            content: const Text(
              'Die Eingaben in diesem Foto-Entwurf werden ersetzt. Dein gespeicherter Wochenplan bleibt erhalten.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Abbrechen'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Entwurf ersetzen'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _pick(bool camera) async {
    if (!await _confirmDiscard() || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final photo = await _source.pick(camera: camera);
      if (!mounted || photo == null) return;
      setState(() {
        _photo = photo;
        _selected.clear();
        _drafts.clear();
        _notes = '';
        _recognizedText = '';
        for (final controller in _controllers.values) {
          controller.clear();
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _message(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  String _message(Object error) {
    if (error is PlatformException) {
      return error.message ??
          'Kamera oder Fotos sind nicht verfügbar. Bitte den Zugriff in den Systemeinstellungen erlauben.';
    }
    if (error is FormatException) return error.message;
    return 'Das Foto konnte nicht verarbeitet werden. Bitte erneut versuchen oder die Mahlzeiten unten eintragen.';
  }

  Future<void> _recognize() async {
    if (!await _confirmDiscard() || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final draft = await widget.recognize!(_photo!);
      if (!mounted) return;
      setState(() {
        _drafts.clear();
        _selected.clear();
        for (final controller in _controllers.values) {
          controller.clear();
        }
        for (final day in draft.days) {
          _drafts[day.weekday] = day;
          _controllers[day.weekday]!.text = day.meal;
          if (day.meal.isNotEmpty &&
              !day.uncertain &&
              _existing(day.weekday).isEmpty) {
            _selected.add(day.weekday);
          }
        }
        _notes = draft.notes;
        _recognizedText = draft.recognizedText;
        if (!draft.days.any((day) => day.meal.isNotEmpty)) {
          _error =
              'Keine Mahlzeiten sicher erkannt. Bitte das Foto prüfen und die Felder ergänzen.';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = _message(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
        });
      }
    }
  }

  Future<void> _save() async {
    final selected = {
      for (final day in _selected)
        if (_controllers[day]!.text.trim().isNotEmpty)
          day: _controllers[day]!.text.trim(),
    };
    if (selected.isEmpty) return;
    final replaced = selected.keys
        .where((day) => _existing(day).isNotEmpty)
        .toList();
    if (replaced.isNotEmpty) {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Geplante Tage ersetzen?'),
          content: Text(
            '${replaced.map((d) => weekdayLabels[d]).join(', ')} werden ersetzt. Bei geänderten Mahlzeiten wird die bisherige Rezeptverknüpfung entfernt. Gespeicherte Rezepte bleiben erhalten.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Diese Tage ersetzen'),
            ),
          ],
        ),
      );
      if (approved != true || !mounted) return;
    }
    if (mounted) Navigator.pop(context, selected);
  }

  @override
  Widget build(BuildContext context) {
    final spellings = {
      for (final day in WeekdayDe.values)
        day: MealSpelling.suggestions(
          _controllers[day]!.text,
          knownPhrases: widget.recipes.map((recipe) => recipe.title),
        ),
    };
    final count = _selected
        .where((d) => _controllers[d]!.text.trim().isNotEmpty)
        .length;
    return Scaffold(
      appBar: AppBar(title: const Text('Wochenplan aus Foto')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '1. Wochenplan fotografieren oder Foto auswählen.\n2. Handschrift auslesen und prüfen.\n3. Gewünschte Tage übernehmen.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _pick(true),
                icon: const Icon(Icons.camera_alt_outlined),
                label: const Text('Foto aufnehmen'),
              ),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _pick(false),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Foto auswählen'),
              ),
            ],
          ),
          if (_photo != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 300,
              child: InteractiveViewer(
                maxScale: 6,
                child: Image.memory(
                  _photo!,
                  fit: BoxFit.contain,
                  errorBuilder: (_, error, stack) =>
                      const Text('Foto kann nicht angezeigt werden.'),
                ),
              ),
            ),
            const Text(
              'Die Erkennung läuft auf diesem Gerät. Dein Foto wird nicht hochgeladen oder im Wochenplan gespeichert.',
            ),
            if (widget.recognize != null)
              FilledButton.icon(
                onPressed: _busy ? null : _recognize,
                icon: const Icon(Icons.document_scanner_outlined),
                label: const Text('Handschrift auslesen'),
              ),
          ],
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: LinearProgressIndicator(),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          const SizedBox(height: 16),
          const Text(
            'Entwurf prüfen',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const Text(
            'Alle Texte sind editierbar. Nur angehakte Tage werden gespeichert. Bestehende und unsichere Tage bitte ausdrücklich auswählen. Rezepte und Zutaten kannst du danach im Wochenplan ergänzen.',
          ),
          if (_notes.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(_notes),
            ),
          if (_recognizedText.isNotEmpty)
            ExpansionTile(
              title: const Text('Gesamten erkannten Text anzeigen'),
              children: [
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(_recognizedText),
                ),
              ],
            ),
          for (final day in WeekdayDe.values)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(weekdayLabels[day]!),
                      subtitle: _existing(day).isEmpty
                          ? null
                          : Text('Bisher: ${_existing(day)}'),
                      value: _selected.contains(day),
                      onChanged: _busy
                          ? null
                          : (checked) => setState(() {
                              if (checked == true) {
                                _selected.add(day);
                              } else {
                                _selected.remove(day);
                              }
                            }),
                    ),
                    TextField(
                      controller: _controllers[day],
                      enabled: !_busy,
                      maxLength: 300,
                      minLines: 1,
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Mahlzeit am ${weekdayLabels[day]}',
                        counterText: '',
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    if (spellings[day]!.isNotEmpty) ...[
                      const Text('Schreibweise prüfen · Küchenwörter DE/CH/EN'),
                      Wrap(
                        spacing: 8,
                        children: [
                          for (final suggestion in spellings[day]!)
                            ActionChip(
                              label: Text(suggestion),
                              onPressed: _busy
                                  ? null
                                  : () => setState(() {
                                      _controllers[day]!.text = suggestion;
                                    }),
                            ),
                        ],
                      ),
                    ],
                    if (_drafts[day]?.uncertain == true)
                      const Text(
                        'Bitte prüfen: Handschrift oder Zuordnung unsicher.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    if (_drafts[day]?.note.isNotEmpty == true)
                      Text(_drafts[day]!.note),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy || count == 0 ? null : _save,
            child: Text('$count Tage in den Wochenplan übernehmen'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen – Wochenplan behalten'),
          ),
        ],
      ),
    );
  }
}

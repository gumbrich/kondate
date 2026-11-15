import 'dart:math' as math;

import 'package:core/core.dart';
import 'package:flutter/services.dart';

import 'photo_week_plan.dart';

/// Swappable on-device OCR boundary. Neither this service nor the native
/// implementations send images to the backend or a model provider.
class LocalWeekPlanRecognizer {
  static const _channel = MethodChannel('kondate/week_plan_text');

  Future<PhotoWeekDraft> recognize(Uint8List photo) async {
    try {
      final raw = await _channel.invokeListMethod<dynamic>('recognize', photo);
      final lines = (raw ?? [])
          .map(
            (item) => RecognizedPhotoLine.fromMap(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
      return draftFromLines(lines);
    } on MissingPluginException {
      throw const FormatException(
        'Auf diesem Gerät ist noch keine Texterkennung verfügbar. Bitte die Mahlzeiten vom Foto unten eintragen.',
      );
    }
  }

  /// Group only text beside an explicitly recognized weekday. Do not guess
  /// missing weekdays or assign all following text to the last recognized day.
  static PhotoWeekDraft draftFromLines(List<RecognizedPhotoLine> input) {
    final lines = [...input]..sort((a, b) => a.centerY.compareTo(b.centerY));
    final anchors =
        <({RecognizedPhotoLine line, WeekdayDe day, String meal})>[];
    for (final line in lines) {
      final match = _weekdayPattern.firstMatch(line.text.trim());
      if (match == null) continue;
      final day = _weekdayNames[match.group(1)!.toLowerCase()]!;
      anchors.add((
        line: line,
        day: day,
        meal: line.text.trim().substring(match.end).trim(),
      ));
    }
    final duplicateDays = <WeekdayDe>{};
    final seen = <WeekdayDe>{};
    for (final anchor in anchors) {
      if (!seen.add(anchor.day)) duplicateDays.add(anchor.day);
    }
    final grouped = <WeekdayDe, List<RecognizedPhotoLine>>{};
    for (final line in lines) {
      if (anchors.any((anchor) => identical(anchor.line, line))) continue;
      final candidates = anchors
          .where(
            (anchor) =>
                !duplicateDays.contains(anchor.day) &&
                line.x >= anchor.line.x + anchor.line.width - 0.02 &&
                (line.centerY - anchor.line.centerY).abs() <=
                    math.max(line.height, anchor.line.height) * 0.85,
          )
          .toList();
      // Two plausible weekday rows are ambiguous; leave them in raw text.
      if (candidates.length == 1 && line.text.trim().length >= 3) {
        (grouped[candidates.single.day] ??= []).add(line);
      }
    }
    final days = <PhotoMealDraft>[];
    for (final anchor in anchors) {
      if (duplicateDays.contains(anchor.day)) continue;
      final fragments = grouped[anchor.day] ?? [];
      fragments.sort((a, b) => a.x.compareTo(b.x));
      final meal = [
        anchor.meal,
        ...fragments.map((l) => l.text),
      ].where((text) => text.trim().isNotEmpty).join(' ').trim();
      days.add(
        PhotoMealDraft(
          weekday: anchor.day,
          meal: meal.length > 300 ? meal.substring(0, 300) : meal,
          uncertain: true,
          note:
              'Automatisch gelesener Text. Bitte mit dem Foto vergleichen, korrigieren und den Tag anhaken.',
        ),
      );
    }
    days.sort((a, b) => a.weekday.index.compareTo(b.weekday.index));
    return PhotoWeekDraft(
      days: days,
      notes: duplicateDays.isNotEmpty
          ? 'Mehrfach erkannte Wochentage wurden nicht zugeordnet: ${duplicateDays.map((d) => weekdayLabels[d]).join(', ')}.'
          : 'Handschrift kann unvollständig oder falsch gelesen werden. Fehlende Tage und Zusatzzeilen bitte selbst ergänzen.',
      recognizedText: lines.map((line) => line.text).join('\n'),
    );
  }

  static final _weekdayPattern = RegExp(
    r'^(montag|dienstag|mittwoch|donnerstag|freitag|samstag|sonntag|mo|di|mi|do|fr|sa|so)(?:l$|(?=$|[\s:.)|/\]\-])[\s:.)|/\]\-]*)',
    caseSensitive: false,
  );
  static const _weekdayNames = {
    'mo': WeekdayDe.montag,
    'montag': WeekdayDe.montag,
    'di': WeekdayDe.dienstag,
    'dienstag': WeekdayDe.dienstag,
    'mi': WeekdayDe.mittwoch,
    'mittwoch': WeekdayDe.mittwoch,
    'do': WeekdayDe.donnerstag,
    'donnerstag': WeekdayDe.donnerstag,
    'fr': WeekdayDe.freitag,
    'freitag': WeekdayDe.freitag,
    'sa': WeekdayDe.samstag,
    'samstag': WeekdayDe.samstag,
    'so': WeekdayDe.sonntag,
    'sonntag': WeekdayDe.sonntag,
  };
}

class RecognizedPhotoLine {
  const RecognizedPhotoLine(
    this.text, {
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });
  final String text;
  // Normalized coordinates, top-left origin, on both platforms.
  final double x, y, width, height;
  double get centerY => y + height / 2;

  factory RecognizedPhotoLine.fromMap(Map<String, dynamic> raw) {
    final text = raw['text'];
    final values = [
      'x',
      'y',
      'width',
      'height',
    ].map((key) => raw[key]).toList();
    if (text is! String ||
        values.any((v) => v is! num || !v.isFinite || v < 0 || v > 1)) {
      throw const FormatException(
        'Texterkennung konnte nicht gelesen werden. Bitte erneut versuchen.',
      );
    }
    return RecognizedPhotoLine(
      text,
      x: (values[0] as num).toDouble(),
      y: (values[1] as num).toDouble(),
      width: (values[2] as num).toDouble(),
      height: (values[3] as num).toDouble(),
    );
  }
}

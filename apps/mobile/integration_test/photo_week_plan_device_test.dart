import 'dart:ui' as ui;

import 'package:core/core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mobile/local_week_plan_recognizer.dart';
import 'package:mobile/week_plan_photo_source.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native offline OCR reads a synthetic seven-day plan', (
    tester,
  ) async {
    // No real photos, saved preferences, household data, or backend calls.
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Offline photo recognition test')),
        ),
      ),
    );
    const labels = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    const meals = [
      'Pasta',
      'Curry',
      'Suppe',
      'Salat',
      'Pizza',
      'Risotto',
      'Kartoffeln',
    ];
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 900, 1100),
      Paint()..color = Colors.white,
    );
    for (var i = 0; i < 7; i++) {
      final painter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: '${labels[i]}) ${meals[i]}',
          style: const TextStyle(
            fontFamily: 'Arial',
            fontSize: 48,
            color: Colors.black,
          ),
        ),
      );
      painter.layout();
      painter.paint(canvas, Offset(60, 60 + i * 140));
      painter.dispose();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(900, 1100);
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final normalized = await WeekPlanPhotoSource.normalize(
      png!.buffer.asUint8List(),
    );
    image.dispose();
    picture.dispose();
    final draft = await LocalWeekPlanRecognizer().recognize(normalized);
    expect(draft.days.map((d) => d.weekday), WeekdayDe.values);
    expect(draft.days.map((d) => d.meal), meals);
    expect(draft.days.every((d) => d.uncertain), true);
  });
}

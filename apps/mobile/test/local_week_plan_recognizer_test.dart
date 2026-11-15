import 'package:core/core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobile/local_week_plan_recognizer.dart';

RecognizedPhotoLine line(
  String text,
  double y, {
  double x = 0.1,
  double width = 0.15,
}) => RecognizedPhotoLine(text, x: x, y: y, width: width, height: 0.04);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'maps explicit weekdays and same-row text without guessing missing days',
    () {
      final draft = LocalWeekPlanRecognizer.draftFromLines([
        line('Mo) Pasta', 0.1),
        line('Do)', 0.5),
        line('Salat', 0.51, x: 0.35),
        line('bei Freunden', 0.35, x: 0.35),
        line('Fr: lasagne', 0.6),
        line('Suppe', 0.8, x: 0.4),
      ]);
      expect(draft.days.map((d) => d.weekday), [
        WeekdayDe.montag,
        WeekdayDe.donnerstag,
        WeekdayDe.freitag,
      ]);
      expect(draft.days.map((d) => d.meal), ['Pasta', 'Salat', 'lasagne']);
      expect(draft.days.every((d) => d.uncertain), true);
      expect(draft.recognizedText, contains('bei Freunden'));
      expect(draft.recognizedText, contains('Suppe'));
    },
  );

  test(
    'recognizes all seven German labels, including a misread closing bracket',
    () {
      final draft = LocalWeekPlanRecognizer.draftFromLines([
        line('Montag: Pasta', 0.1),
        line('Di) Curry', 0.2),
        line('Mil', 0.3),
        line('Donnerstag: Suppe', 0.4),
        line('Fr) Pizza', 0.5),
        line('Sa. Salat', 0.6),
        line('So / Risotto', 0.7),
      ]);
      expect(draft.days.map((d) => d.weekday), WeekdayDe.values);
      expect(draft.days[2].meal, isEmpty);
    },
  );

  test('duplicates, non-day words and ambiguous rows remain unassigned', () {
    final draft = LocalWeekPlanRecognizer.draftFromLines([
      line('Mo) Pasta', 0.1),
      line('Mo) Curry', 0.2),
      line('Di)', 0.4),
      line('Mi)', 0.42),
      line('Suppe', 0.41, x: 0.4),
      line('Miso Suppe', 0.6),
      line('Salat', 0.7),
      line('Frischkäse', 0.8),
    ]);
    expect(draft.days.map((d) => d.weekday), [
      WeekdayDe.dienstag,
      WeekdayDe.mittwoch,
    ]);
    expect(draft.days.every((d) => d.meal.isEmpty), true);
    expect(draft.notes, contains('Montag'));
  });

  test('blank recognition returns an empty editable draft', () {
    expect(LocalWeekPlanRecognizer.draftFromLines([]).days, isEmpty);
  });

  test(
    'uses only the local native channel and normalizes coordinates',
    () async {
      const channel = MethodChannel('kondate/week_plan_text');
      var calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            calls++;
            expect(call.method, 'recognize');
            expect(call.arguments, Uint8List.fromList([1, 2, 3]));
            return [
              {
                'text': 'Mo) Pasta',
                'x': 0.1,
                'y': 0.1,
                'width': 0.4,
                'height': 0.05,
              },
            ];
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null),
      );
      final draft = await LocalWeekPlanRecognizer().recognize(
        Uint8List.fromList([1, 2, 3]),
      );
      expect(calls, 1);
      expect(draft.days.single.meal, 'Pasta');
    },
  );

  test('rejects corrupt native geometry', () {
    expect(
      () => RecognizedPhotoLine.fromMap({
        'text': 'Mo',
        'x': double.nan,
        'y': 0.1,
        'width': 0.1,
        'height': 0.1,
      }),
      throwsFormatException,
    );
  });

  test('clips small OCR boundary overshoots and keeps the recognized text', () {
    final line = RecognizedPhotoLine.fromMap({
      'text': 'Mo) Pasta',
      'x': -0.0001,
      'y': 0.99,
      'width': 0.4,
      'height': 0.0101,
    });
    expect(line.x, 0);
    expect(line.width, closeTo(0.3999, 0.00001));
    expect(line.y + line.height, 1);
    expect(
      LocalWeekPlanRecognizer.draftFromLines([line]).days.single.meal,
      'Pasta',
    );
  });
}

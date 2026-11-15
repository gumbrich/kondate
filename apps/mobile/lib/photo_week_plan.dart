import 'package:core/core.dart';

const weekdayLabels = <WeekdayDe, String>{
  WeekdayDe.montag: 'Montag',
  WeekdayDe.dienstag: 'Dienstag',
  WeekdayDe.mittwoch: 'Mittwoch',
  WeekdayDe.donnerstag: 'Donnerstag',
  WeekdayDe.freitag: 'Freitag',
  WeekdayDe.samstag: 'Samstag',
  WeekdayDe.sonntag: 'Sonntag',
};

class PhotoMealDraft {
  const PhotoMealDraft({
    required this.weekday,
    required this.meal,
    this.note = '',
    this.uncertain = false,
  });
  final WeekdayDe weekday;
  final String meal;
  final String note;
  final bool uncertain;
}

class PhotoWeekDraft {
  const PhotoWeekDraft({
    required this.days,
    this.notes = '',
    this.recognizedText = '',
  });
  final List<PhotoMealDraft> days;
  final String notes;
  final String recognizedText;
}

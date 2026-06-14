import 'package:course_table/custom_event.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final once = CustomEvent(
    id: '1',
    title: '考试',
    location: '八教',
    date: DateTime(2026, 6, 15),
    startMinutes: 540,
    endMinutes: 600,
    weekly: false,
    reminderMinutes: 15,
  );
  final weekly = CustomEvent(
    id: '2',
    title: '社团活动',
    location: '活动室',
    date: DateTime(2026, 6, 16),
    startMinutes: 1080,
    endMinutes: 1140,
    weekly: true,
    reminderMinutes: 30,
  );

  test('one-time event only occurs on selected date', () {
    expect(once.occursOn(DateTime(2026, 6, 15)), isTrue);
    expect(once.occursOn(DateTime(2026, 6, 22)), isFalse);
  });

  test('weekly event repeats after its starting date', () {
    expect(weekly.occursOn(DateTime(2026, 6, 23)), isTrue);
    expect(weekly.occursOn(DateTime(2026, 6, 15)), isFalse);
  });

  test('daily events are sorted by start time', () {
    expect(customEventsForDate([weekly, once], DateTime(2026, 6, 16)), [weekly]);
    expect(weekly.startOn(DateTime(2026, 6, 23)), DateTime(2026, 6, 23, 18));
  });
}

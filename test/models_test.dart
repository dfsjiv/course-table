import 'package:course_table/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const course = Course(
    name: '离散数学',
    weekday: 3,
    startPeriod: 1,
    endPeriod: 2,
    weeks: [1, 3, 5],
    campus: '校本部',
    room: '八教202',
    teacher: '刘老师',
  );
  final timetable = Timetable(
    semester: '2025-2026年第2学期',
    className: '计科2502',
    startDate: DateTime(2026, 3, 2),
    totalWeeks: 20,
    courses: const [course],
  );

  test('filters courses by selected week', () {
    expect(timetable.coursesForWeek(3), [course]);
    expect(timetable.coursesForWeek(4), isEmpty);
  });

  test('calculates and clamps current week', () {
    expect(timetable.weekFor(DateTime(2026, 3, 2)), 1);
    expect(timetable.weekFor(DateTime(2026, 6, 8)), 15);
    expect(timetable.weekFor(DateTime(2027, 1, 1)), 20);
  });
}

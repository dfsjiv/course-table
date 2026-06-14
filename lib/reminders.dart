import 'models.dart';

const periodStartTimes = [
  (8, 0),
  (8, 55),
  (10, 0),
  (10, 55),
  (14, 0),
  (14, 55),
  (16, 0),
  (16, 55),
  (19, 0),
  (19, 55),
  (21, 0),
  (21, 55),
];

class CourseOccurrence {
  const CourseOccurrence({
    required this.course,
    required this.start,
  });

  final Course course;
  final DateTime start;
}

DateTime courseStart(DateTime date, Course course) {
  final time = periodStartTimes[course.startPeriod - 1];
  return DateTime(date.year, date.month, date.day, time.$1, time.$2);
}

CourseOccurrence? nextCourse(Timetable timetable, DateTime now) {
  for (var offset = 0; offset <= 140; offset++) {
    final date = DateTime(now.year, now.month, now.day).add(Duration(days: offset));
    for (final course in timetable.coursesForDate(date)) {
      final start = courseStart(date, course);
      if (start.isAfter(now)) return CourseOccurrence(course: course, start: start);
    }
  }
  return null;
}

List<CourseOccurrence> futureCourses(
  Timetable timetable,
  DateTime now, {
  int limit = 100,
}) {
  final result = <CourseOccurrence>[];
  for (var offset = 0; offset <= 140 && result.length < limit; offset++) {
    final date = DateTime(now.year, now.month, now.day).add(Duration(days: offset));
    for (final course in timetable.coursesForDate(date)) {
      final start = courseStart(date, course);
      if (start.isAfter(now)) result.add(CourseOccurrence(course: course, start: start));
      if (result.length == limit) break;
    }
  }
  return result;
}

String countdownText(Duration duration) {
  final totalSeconds = duration.inSeconds.clamp(0, 999999999);
  final days = totalSeconds ~/ 86400;
  final hours = (totalSeconds % 86400) ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  final time = '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
  return days > 0 ? '$days天 $time' : time;
}

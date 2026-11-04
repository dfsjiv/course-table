import 'custom_event.dart';
import 'models.dart';

const defaultPeriodStartTimes = [
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

/// Every period lasts 45 minutes by default. The Kotlin island service
/// mirrors both defaults — keep them in sync.
const defaultPeriodLengthMinutes = 45;

/// The active daily schedule (作息时间). Defaults until [applySchedule]
/// installs a timetable's own times.
List<(int, int)> periodStartTimes = defaultPeriodStartTimes;
int periodLengthMinutes = defaultPeriodLengthMinutes;

/// Installs [timetable]'s custom schedule, or the default when it has none.
void applySchedule(Timetable? timetable) {
  final starts = timetable?.periodStarts;
  periodStartTimes =
      starts == null || starts.length != defaultPeriodStartTimes.length
      ? defaultPeriodStartTimes
      : [for (final minutes in starts) (minutes ~/ 60, minutes % 60)];
  periodLengthMinutes = timetable?.periodLength ?? defaultPeriodLengthMinutes;
}

DateTime courseEnd(DateTime date, Course course) {
  final time = periodStartTimes[course.endPeriod - 1];
  return DateTime(
    date.year,
    date.month,
    date.day,
    time.$1,
    time.$2,
  ).add(Duration(minutes: periodLengthMinutes));
}

/// The course currently in progress (start inclusive, end exclusive).
class CurrentCourse {
  const CurrentCourse({
    required this.course,
    required this.start,
    required this.end,
  });

  final Course course;
  final DateTime start;
  final DateTime end;

  int minutesLeft(DateTime now) =>
      ((end.difference(now).inSeconds + 59) ~/ 60).clamp(0, 9999);
}

CurrentCourse? currentCourse(Timetable timetable, DateTime now) {
  for (final course in timetable.coursesForDate(now)) {
    final start = courseStart(now, course);
    final end = courseEnd(now, course);
    if (!now.isBefore(start) && now.isBefore(end)) {
      return CurrentCourse(course: course, start: start, end: end);
    }
  }
  return null;
}

/// Display state for the system dynamic island. Courses only, today only.
sealed class IslandState {
  const IslandState();
}

class IslandInClass extends IslandState {
  const IslandInClass(this.current);
  final CurrentCourse current;
}

class IslandUpNext extends IslandState {
  const IslandUpNext(this.occurrence);
  final CourseOccurrence occurrence;
}

IslandState? islandState(Timetable timetable, DateTime now) {
  // Mirrors IslandService.kt: no start date, no island.
  if (timetable.startDate == null) return null;
  final current = currentCourse(timetable, now);
  if (current != null) return IslandInClass(current);
  final tomorrow = DateTime(
    now.year,
    now.month,
    now.day,
  ).add(const Duration(days: 1));
  final next = nextCourse(timetable, now);
  if (next != null && next.start.isBefore(tomorrow)) {
    return IslandUpNext(next);
  }
  return null;
}

class CourseOccurrence {
  const CourseOccurrence({required this.course, required this.start});

  final Course course;
  final DateTime start;
}

/// The nearest upcoming item, either an imported course or a custom event.
class NextUp {
  const NextUp({
    required this.title,
    required this.location,
    required this.start,
  });

  final String title;
  final String location;
  final DateTime start;
}

DateTime courseStart(DateTime date, Course course) {
  final time = periodStartTimes[course.startPeriod - 1];
  return DateTime(date.year, date.month, date.day, time.$1, time.$2);
}

CourseOccurrence? nextCourse(Timetable timetable, DateTime now) {
  for (var offset = 0; offset <= 140; offset++) {
    final date = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: offset));
    for (final course in timetable.coursesForDate(date)) {
      final start = courseStart(date, course);
      if (start.isAfter(now)) {
        return CourseOccurrence(course: course, start: start);
      }
    }
  }
  return null;
}

/// Merges imported courses and custom events into the single nearest upcoming
/// item. An event only wins when it starts strictly before the next course.
NextUp? nextUp(Timetable timetable, List<CustomEvent> events, DateTime now) {
  final course = nextCourse(timetable, now);
  CustomEvent? nextEvent;
  DateTime? nextEventStart;
  for (var offset = 0; offset <= 120 && nextEvent == null; offset++) {
    final date = dateOnly(now).add(Duration(days: offset));
    for (final event in customEventsForDate(events, date)) {
      final start = event.startOn(date);
      if (start.isAfter(now)) {
        nextEvent = event;
        nextEventStart = start;
        break;
      }
    }
  }
  if (course != null &&
      (nextEventStart == null || !course.start.isAfter(nextEventStart))) {
    return NextUp(
      title: course.course.name,
      location: course.course.room,
      start: course.start,
    );
  }
  if (nextEvent != null) {
    return NextUp(
      title: nextEvent.title,
      location: nextEvent.location,
      start: nextEventStart!,
    );
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
    final date = DateTime(
      now.year,
      now.month,
      now.day,
    ).add(Duration(days: offset));
    for (final course in timetable.coursesForDate(date)) {
      final start = courseStart(date, course);
      if (start.isAfter(now)) {
        result.add(CourseOccurrence(course: course, start: start));
      }
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
  final time =
      '${hours.toString().padLeft(2, '0')}:'
      '${minutes.toString().padLeft(2, '0')}:'
      '${seconds.toString().padLeft(2, '0')}';
  return days > 0 ? '$days天 $time' : time;
}

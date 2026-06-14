class Course {
  const Course({
    required this.name,
    required this.weekday,
    required this.startPeriod,
    required this.endPeriod,
    required this.weeks,
    required this.campus,
    required this.room,
    required this.teacher,
  });

  final String name;
  final int weekday;
  final int startPeriod;
  final int endPeriod;
  final List<int> weeks;
  final String campus;
  final String room;
  final String teacher;

  factory Course.fromJson(Map<String, dynamic> json) => Course(
        name: json['name'] as String,
        weekday: json['weekday'] as int,
        startPeriod: json['startPeriod'] as int,
        endPeriod: json['endPeriod'] as int,
        weeks: (json['weeks'] as List).cast<int>(),
        campus: json['campus'] as String,
        room: json['room'] as String,
        teacher: json['teacher'] as String,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'weekday': weekday,
        'startPeriod': startPeriod,
        'endPeriod': endPeriod,
        'weeks': weeks,
        'campus': campus,
        'room': room,
        'teacher': teacher,
      };
}

class Timetable {
  const Timetable({
    required this.semester,
    required this.className,
    required this.startDate,
    required this.totalWeeks,
    required this.courses,
  });

  final String semester;
  final String className;
  final DateTime? startDate;
  final int totalWeeks;
  final List<Course> courses;

  factory Timetable.fromJson(Map<String, dynamic> json) => Timetable(
        semester: json['semester'] as String,
        className: json['className'] as String,
        startDate: DateTime.tryParse(json['startDate'] as String),
        totalWeeks: json['totalWeeks'] as int,
        courses: (json['courses'] as List)
            .map((course) => Course.fromJson(course as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'semester': semester,
        'className': className,
        'startDate': startDate?.toIso8601String().split('T').first ?? '',
        'totalWeeks': totalWeeks,
        'courses': courses.map((course) => course.toJson()).toList(),
      };

  List<Course> coursesForWeek(int week) =>
      courses.where((course) => course.weeks.contains(week)).toList();

  List<Course> coursesForDate(DateTime date) {
    final week = weekFor(date);
    return courses
        .where((course) =>
            course.weekday == date.weekday && course.weeks.contains(week))
        .toList()
      ..sort((a, b) => a.startPeriod.compareTo(b.startPeriod));
  }

  DateTime? dateFor(int week, int weekday) {
    if (startDate == null) return null;
    return DateTime(startDate!.year, startDate!.month, startDate!.day)
        .add(Duration(days: (week - 1) * 7 + weekday - 1));
  }

  int weekFor(DateTime date) {
    if (startDate == null) return 1;
    final day = DateTime(date.year, date.month, date.day);
    final first = DateTime(startDate!.year, startDate!.month, startDate!.day);
    return (day.difference(first).inDays ~/ 7 + 1).clamp(1, totalWeeks);
  }
}

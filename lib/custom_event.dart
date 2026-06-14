class CustomEvent {
  const CustomEvent({
    required this.id,
    required this.title,
    required this.location,
    required this.date,
    required this.startMinutes,
    required this.endMinutes,
    required this.weekly,
    required this.reminderMinutes,
  });

  final String id;
  final String title;
  final String location;
  final DateTime date;
  final int startMinutes;
  final int endMinutes;
  final bool weekly;
  final int reminderMinutes;

  bool occursOn(DateTime target) =>
      weekly
          ? target.weekday == date.weekday && !target.isBefore(dateOnly(date))
          : sameDate(target, date);

  DateTime startOn(DateTime target) => DateTime(
        target.year,
        target.month,
        target.day,
        startMinutes ~/ 60,
        startMinutes % 60,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'location': location,
        'date': date.toIso8601String(),
        'startMinutes': startMinutes,
        'endMinutes': endMinutes,
        'weekly': weekly,
        'reminderMinutes': reminderMinutes,
      };

  factory CustomEvent.fromJson(Map<String, dynamic> json) => CustomEvent(
        id: json['id'] as String,
        title: json['title'] as String,
        location: json['location'] as String,
        date: DateTime.parse(json['date'] as String),
        startMinutes: json['startMinutes'] as int,
        endMinutes: json['endMinutes'] as int,
        weekly: json['weekly'] as bool,
        reminderMinutes: json['reminderMinutes'] as int,
      );
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

bool sameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

List<CustomEvent> customEventsForDate(List<CustomEvent> events, DateTime date) =>
    events.where((event) => event.occursOn(date)).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));


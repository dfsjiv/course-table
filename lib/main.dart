import 'dart:async';
import 'dart:ui' show FontFeature;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'models.dart';
import 'notification_service.dart';
import 'reminders.dart';
import 'storage.dart';
import 'xls_parser.dart';

void main() => runApp(const CourseTableApp());

class CourseTableApp extends StatelessWidget {
  const CourseTableApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '课表',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff2563eb)),
        scaffoldBackgroundColor: const Color(0xfff7f8fc),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _storage = TimetableStorage();
  final _notifications = NotificationService();
  Timetable? _timetable;
  DateTime _selectedDate = _today();
  DateTime _now = DateTime.now();
  Timer? _clock;
  int _reminderMinutes = 15;
  bool _weekView = false;
  bool _loading = true;

  static DateTime _today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  @override
  void initState() {
    super.initState();
    _load();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    final timetable = await _storage.load();
    final reminderMinutes = await _storage.loadReminderMinutes();
    await _notifications.initialize();
    if (timetable != null) {
      await _notifications.schedule(timetable, reminderMinutes);
    }
    if (!mounted) return;
    setState(() {
      _timetable = timetable;
      _reminderMinutes = reminderMinutes;
      _loading = false;
    });
  }

  Future<void> _import() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['xls'],
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;
    try {
      final timetable = XlsParser().parse(bytes);
      await _storage.save(timetable);
      await _notifications.requestPermission();
      await _notifications.schedule(timetable, _reminderMinutes);
      if (!mounted) return;
      setState(() {
        _timetable = timetable;
        _selectedDate = _today();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$error')),
      );
    }
  }

  Future<void> _chooseReminder() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('课前提醒'),
        children: [
          for (final minutes in [0, 5, 10, 15, 30, 60])
            RadioListTile<int>(
              value: minutes,
              groupValue: _reminderMinutes,
              title: Text(minutes == 0 ? '关闭提醒' : '提前 $minutes 分钟'),
              onChanged: (value) => Navigator.pop(context, value),
            ),
        ],
      ),
    );
    if (selected == null) return;
    await _storage.saveReminderMinutes(selected);
    if (selected > 0) await _notifications.requestPermission();
    final timetable = _timetable;
    if (timetable != null) await _notifications.schedule(timetable, selected);
    if (!mounted) return;
    setState(() => _reminderMinutes = selected);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final timetable = _timetable;
    if (timetable == null) return _EmptyPage(onImport: _import);

    final week = timetable.weekFor(_selectedDate);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Text(timetable.className.isEmpty ? '我的课表' : timetable.className),
        actions: [
          IconButton(
            tooltip: '课前提醒',
            onPressed: _chooseReminder,
            icon: Icon(
              _reminderMinutes == 0
                  ? Icons.notifications_off_outlined
                  : Icons.notifications_active_outlined,
            ),
          ),
          IconButton(
            tooltip: _weekView ? '按天显示' : '整周课表',
            onPressed: () => setState(() => _weekView = !_weekView),
            icon: Icon(_weekView ? Icons.view_day_outlined : Icons.calendar_view_week),
          ),
          IconButton(
            tooltip: '重新导入',
            onPressed: _import,
            icon: const Icon(Icons.file_open_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          _DateHeader(
            date: _selectedDate,
            week: week,
            onToday: () => setState(() => _selectedDate = _today()),
          ),
          _DayStrip(
            timetable: timetable,
            selectedDate: _selectedDate,
            onSelected: (date) => setState(() => _selectedDate = date),
          ),
          _NextCourseBanner(timetable: timetable, now: _now),
          Expanded(
            child: _weekView
                ? TimetableGrid(courses: timetable.coursesForWeek(week))
                : DaySchedule(
                    date: _selectedDate,
                    courses: timetable.coursesForDate(_selectedDate),
                  ),
          ),
        ],
      ),
    );
  }
}

class _EmptyPage extends StatelessWidget {
  const _EmptyPage({required this.onImport});
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month_outlined, size: 72),
            const SizedBox(height: 16),
            const Text('还没有课表', style: TextStyle(fontSize: 22)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onImport,
              icon: const Icon(Icons.file_open),
              label: const Text('导入易班课表 (.xls)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({
    required this.date,
    required this.week,
    required this.onToday,
  });

  final DateTime date;
  final int week;
  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 12, 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('第 $week 周', style: Theme.of(context).textTheme.headlineSmall),
                Text(
                  '${date.month}月${date.day}日  ${_weekdays[date.weekday - 1]}',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onToday,
            icon: const Icon(Icons.today_outlined),
            label: const Text('今天'),
          ),
        ],
      ),
    );
  }
}

class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.timetable,
    required this.selectedDate,
    required this.onSelected,
  });

  final Timetable timetable;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  @override
  Widget build(BuildContext context) {
    final monday = selectedDate.subtract(Duration(days: selectedDate.weekday - 1));
    return SizedBox(
      height: 78,
      child: Row(
        children: [
          IconButton(
            onPressed: () => onSelected(selectedDate.subtract(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 7,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, index) {
                final date = monday.add(Duration(days: index));
                final selected = _sameDay(date, selectedDate);
                final today = _sameDay(date, _HomePageState._today());
                return InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onSelected(date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 54,
                    decoration: BoxDecoration(
                      color: selected ? Theme.of(context).colorScheme.primary : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: today
                          ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _shortWeekdays[index],
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.black54,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${date.day}',
                          style: TextStyle(
                            color: selected ? Colors.white : Colors.black87,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          IconButton(
            onPressed: () => onSelected(selectedDate.add(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

class _NextCourseBanner extends StatelessWidget {
  const _NextCourseBanner({required this.timetable, required this.now});

  final Timetable timetable;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final next = nextCourse(timetable, now);
    if (next == null) return const SizedBox.shrink();
    final duration = next.start.difference(now);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xff2563eb), Color(0xff4f46e5)],
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '下一节 · ${next.course.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  next.course.room.isEmpty
                      ? '第${next.course.startPeriod}-${next.course.endPeriod}节'
                      : next.course.room,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            countdownText(duration),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w700,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class DaySchedule extends StatelessWidget {
  const DaySchedule({super.key, required this.date, required this.courses});
  final DateTime date;
  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    if (courses.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.free_breakfast_outlined, size: 58, color: Colors.black38),
            SizedBox(height: 12),
            Text('今天没有课', style: TextStyle(fontSize: 18, color: Colors.black54)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 28),
      itemCount: courses.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) => _DayCourseCard(course: courses[index]),
    );
  }
}

class _DayCourseCard extends StatelessWidget {
  const _DayCourseCard({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    final color = _courseColor(course.name);
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(width: 7, decoration: BoxDecoration(color: color, borderRadius: const BorderRadius.horizontal(left: Radius.circular(18)))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${course.startPeriod}-${course.endPeriod}节', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                  const SizedBox(height: 4),
                  Text(_periodTime(course.startPeriod), style: const TextStyle(fontSize: 12, color: Colors.black45)),
                ],
              ),
            ),
            const VerticalDivider(indent: 14, endIndent: 14, width: 1),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(course.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    if (course.room.isNotEmpty) _Detail(icon: Icons.location_on_outlined, text: course.room),
                    if (course.teacher.isNotEmpty) _Detail(icon: Icons.person_outline, text: course.teacher),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.black45),
          const SizedBox(width: 5),
          Expanded(child: Text(text, style: const TextStyle(color: Colors.black54))),
        ],
      ),
    );
  }
}

class TimetableGrid extends StatelessWidget {
  const TimetableGrid({super.key, required this.courses});
  final List<Course> courses;

  @override
  Widget build(BuildContext context) {
    const labelWidth = 42.0;
    const columnWidth = 120.0;
    const rowHeight = 58.0;
    const headerHeight = 38.0;
    return InteractiveViewer(
      constrained: false,
      minScale: 0.65,
      maxScale: 1.5,
      child: SizedBox(
        width: labelWidth + columnWidth * 7,
        height: headerHeight + rowHeight * 12,
        child: Stack(
          children: [
            for (var day = 0; day < 7; day++)
              Positioned(left: labelWidth + day * columnWidth, width: columnWidth, height: headerHeight, child: Center(child: Text(_weekdays[day]))),
            for (var period = 1; period <= 12; period++)
              Positioned(top: headerHeight + (period - 1) * rowHeight, width: labelWidth, height: rowHeight, child: Center(child: Text('$period'))),
            for (var day = 0; day <= 7; day++)
              Positioned(left: labelWidth + day * columnWidth, top: headerHeight, child: Container(width: 1, height: rowHeight * 12, color: Colors.black12)),
            for (var period = 0; period <= 12; period++)
              Positioned(left: labelWidth, top: headerHeight + period * rowHeight, child: Container(width: columnWidth * 7, height: 1, color: Colors.black12)),
            for (final course in courses)
              Positioned(
                left: labelWidth + (course.weekday - 1) * columnWidth + 3,
                top: headerHeight + (course.startPeriod - 1) * rowHeight + 3,
                width: columnWidth - 6,
                height: (course.endPeriod - course.startPeriod + 1) * rowHeight - 6,
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(color: _courseColor(course.name).withValues(alpha: 0.22), borderRadius: BorderRadius.circular(8)),
                  child: Text('${course.name}\n${course.room}', overflow: TextOverflow.fade, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

const _weekdays = ['星期一', '星期二', '星期三', '星期四', '星期五', '星期六', '星期日'];
const _shortWeekdays = ['一', '二', '三', '四', '五', '六', '日'];

bool _sameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

Color _courseColor(String name) {
  const colors = [0xff2563eb, 0xff16a34a, 0xffd97706, 0xffdb2777, 0xff7c3aed, 0xff0891b2];
  return Color(colors[name.hashCode.abs() % colors.length]);
}

String _periodTime(int period) {
  const times = ['08:00', '08:55', '10:00', '10:55', '14:00', '14:55', '16:00', '16:55', '19:00', '19:55', '21:00', '21:55'];
  return period > 0 && period <= times.length ? times[period - 1] : '';
}

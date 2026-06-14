import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'models.dart';
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
  Timetable? _timetable;
  int _week = 1;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final timetable = await _storage.load();
    if (!mounted) return;
    setState(() {
      _timetable = timetable;
      _week = timetable?.weekFor(DateTime.now()) ?? 1;
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
      if (!mounted) return;
      setState(() {
        _timetable = timetable;
        _week = timetable.weekFor(DateTime.now());
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('导入失败：$error')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final timetable = _timetable;
    if (timetable == null) {
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
                onPressed: _import,
                icon: const Icon(Icons.file_open),
                label: const Text('导入易班课表 (.xls)'),
              ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(timetable.className.isEmpty ? '课表' : timetable.className),
        actions: [
          IconButton(onPressed: _import, icon: const Icon(Icons.file_open)),
        ],
      ),
      body: Column(
        children: [
          _WeekSwitcher(
            week: _week,
            totalWeeks: timetable.totalWeeks,
            onChanged: (week) => setState(() => _week = week),
          ),
          Expanded(child: TimetableGrid(courses: timetable.coursesForWeek(_week))),
        ],
      ),
    );
  }
}

class _WeekSwitcher extends StatelessWidget {
  const _WeekSwitcher({
    required this.week,
    required this.totalWeeks,
    required this.onChanged,
  });

  final int week;
  final int totalWeeks;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          onPressed: week > 1 ? () => onChanged(week - 1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Text('第 $week 周', style: Theme.of(context).textTheme.titleLarge),
        IconButton(
          onPressed: week < totalWeeks ? () => onChanged(week + 1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class TimetableGrid extends StatelessWidget {
  const TimetableGrid({super.key, required this.courses});

  final List<Course> courses;
  static const dayNames = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];

  @override
  Widget build(BuildContext context) {
    const labelWidth = 44.0;
    const columnWidth = 132.0;
    const rowHeight = 64.0;
    const headerHeight = 42.0;
    const gridWidth = labelWidth + columnWidth * 7;
    const gridHeight = headerHeight + rowHeight * 12;

    return InteractiveViewer(
      constrained: false,
      minScale: 0.7,
      maxScale: 1.5,
      child: SizedBox(
        width: gridWidth,
        height: gridHeight,
        child: Stack(
          children: [
            for (var day = 0; day < 7; day++)
              Positioned(
                left: labelWidth + day * columnWidth,
                width: columnWidth,
                height: headerHeight,
                child: Center(child: Text(dayNames[day])),
              ),
            for (var period = 1; period <= 12; period++)
              Positioned(
                top: headerHeight + (period - 1) * rowHeight,
                width: labelWidth,
                height: rowHeight,
                child: Center(child: Text('$period')),
              ),
            for (var day = 0; day <= 7; day++)
              Positioned(
                left: labelWidth + day * columnWidth,
                top: headerHeight,
                child: Container(width: 1, height: rowHeight * 12, color: Colors.black12),
              ),
            for (var period = 0; period <= 12; period++)
              Positioned(
                left: labelWidth,
                top: headerHeight + period * rowHeight,
                child: Container(width: columnWidth * 7, height: 1, color: Colors.black12),
              ),
            for (final course in courses)
              Positioned(
                left: labelWidth + (course.weekday - 1) * columnWidth + 3,
                top: headerHeight + (course.startPeriod - 1) * rowHeight + 3,
                width: columnWidth - 6,
                height: (course.endPeriod - course.startPeriod + 1) * rowHeight - 6,
                child: _CourseCard(course: course),
              ),
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  const _CourseCard({required this.course});
  final Course course;

  @override
  Widget build(BuildContext context) {
    final colors = [0xffdbeafe, 0xffdcfce7, 0xfffef3c7, 0xfffce7f3, 0xffede9fe];
    final color = Color(colors[course.name.hashCode.abs() % colors.length]);
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => showModalBottomSheet<void>(
          context: context,
          builder: (_) => Padding(
            padding: const EdgeInsets.all(24),
            child: Text('${course.name}\n${course.teacher}\n${course.campus} ${course.room}'),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(7),
          child: Text(
            '${course.name}\n${course.room}',
            overflow: TextOverflow.fade,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}


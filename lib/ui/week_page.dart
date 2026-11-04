import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

import '../custom_event.dart';
import '../models.dart';
import 'actions.dart';
import 'common.dart';
import 'icons.dart';
import 'glass.dart';
import 'semester_page.dart';
import 'sheets.dart';
import 'tokens.dart';
import 'week_grid.dart';

class WeekPage extends StatefulWidget {
  const WeekPage({super.key, required this.reselect});

  final Reselect reselect;

  @override
  State<WeekPage> createState() => WeekPageState();
}

class WeekPageState extends State<WeekPage> {
  final _sheet = SheetController();
  PageController? _pages;
  int _week = 1;
  Layer _layer = Layer.both;
  bool _pickerOpen = false;
  DateTime _now = DateTime.now();
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    widget.reselect.addListener(_toThisWeek);
    // The now line only needs minute precision.
    _clock = Timer.periodic(
      const Duration(seconds: 30),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  void _toThisWeek() {
    final table = AppScope.read(context).timetable;
    if (table != null) _animateTo(_currentWeek(table), table);
  }

  @override
  void dispose() {
    widget.reselect.removeListener(_toThisWeek);
    _clock?.cancel();
    _pages?.dispose();
    _sheet.dispose();
    super.dispose();
  }

  int _currentWeek(Timetable table) => table.weekFor(DateTime.now());

  void jumpToWeek(int week) {
    setState(() => _week = week);
    _pages?.jumpToPage(week - 1);
  }

  void _animateTo(int week, Timetable table) {
    final target = week.clamp(1, table.totalWeeks);
    _pages?.animateToPage(
      target - 1,
      duration: const Duration(milliseconds: 360),
      curve: const Cubic(0.22, 1, 0.36, 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final palette = Palette(context);
    final table = state.timetable;
    if (table == null) {
      return MiuixScaffold(
        containerColor: const Color(0x00000000),
        content: (padding) => Padding(
          padding: padding,
          child: Column(
            children: [
              const PageHeader(title: '课表'),
              const SizedBox(height: 24),
              PageCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '导入课表后，这里一屏显示整周。',
                      style: TypeScale.secondary.copyWith(
                        color: palette.secondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    PrimaryButton(
                      text: '导入课表',
                      icon: AppIcons.fileImport,
                      onPressed: () => importTimetable(context),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (_pages == null) {
      _week = _currentWeek(table);
      _pages = PageController(initialPage: _week - 1);
    }
    final monday = table.dateFor(_week, 1);
    final sunday = table.dateFor(_week, 7);
    final range = monday == null || sunday == null
        ? table.semester
        : '${monday.month}/${monday.day}–${sunday.month}/${sunday.day}'
              '${_week == _currentWeek(table) && table.rawWeekFor(_now) == _week ? ' · 本周' : ''}';

    return MiuixScaffold(
      containerColor: const Color(0x00000000),
      content: (padding) => Stack(
        children: [
          Padding(
            padding: padding,
            child: Column(
              children: [
                PageHeader(
                  title: '第 $_week 周',
                  meta: range,
                  onTitleTap: () => setState(() => _pickerOpen = true),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RoundIconButton(
                        icon: AppIcons.chevronLeft,
                        label: '上一周',
                        onPressed: _week > 1
                            ? () => _animateTo(_week - 1, table)
                            : null,
                      ),
                      const SizedBox(width: 4),
                      GlassTextButton(
                        text: '本周',
                        onPressed: () => _animateTo(_currentWeek(table), table),
                      ),
                      const SizedBox(width: 4),
                      RoundIconButton(
                        icon: AppIcons.chevronRight,
                        label: '下一周',
                        onPressed: _week < table.totalWeeks
                            ? () => _animateTo(_week + 1, table)
                            : null,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: GlassSegmented(
                          labels: layerLabels,
                          icons: const [
                            AppIcons.layers,
                            AppIcons.week,
                            AppIcons.study,
                          ],
                          selected: _layer.index,
                          height: 44,
                          onChanged: (index) =>
                              setState(() => _layer = Layer.values[index]),
                        ),
                      ),
                      const SizedBox(width: 8),
                      RoundIconButton(
                        icon: AppIcons.list,
                        label: '学期总览',
                        onPressed: () async {
                          final week = await Navigator.of(
                            context,
                          ).push<int>(SlideRoute((_) => const SemesterPage()));
                          if (week != null) jumpToWeek(week);
                        },
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _pages,
                    itemCount: table.totalWeeks,
                    onPageChanged: (index) => setState(() => _week = index + 1),
                    itemBuilder: (context, index) => Padding(
                      padding: const EdgeInsets.fromLTRB(4, 0, 6, 8),
                      child: WeekGrid(
                        timetable: table,
                        week: index + 1,
                        layer: _layer,
                        plans: state.plans,
                        showOtherWeeks: state.showOtherWeeks,
                        now: _now,
                        onCourseTap: (course, date) =>
                            _sheet.open(CourseSheetRequest(course, date)),
                        onPlanTap: (plan) =>
                            _sheet.open(PlanSheetRequest(plan.id)),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          SheetLayer(controller: _sheet),
          MiuixOverlayBottomSheet(
            show: _pickerOpen,
            title: '选择周次',
            onDismissRequest: () => setState(() => _pickerOpen = false),
            content: _WeekPicker(
              table: table,
              selected: _week,
              current: table.rawWeekFor(dateOnly(_now)),
              onPick: (week) {
                setState(() => _pickerOpen = false);
                jumpToWeek(week);
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// All weeks as a grid; each tile shows how busy the week is.
class _WeekPicker extends StatelessWidget {
  const _WeekPicker({
    required this.table,
    required this.selected,
    required this.current,
    required this.onPick,
  });

  final Timetable table;
  final int selected;
  final int current;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final palette = Palette(context);
    final counts = [
      for (var week = 1; week <= table.totalWeeks; week++)
        table.coursesForWeek(week).length,
    ];
    final busiest = counts.fold<int>(
      1,
      (max, count) => count > max ? count : max,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GridView.count(
        crossAxisCount: 5,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.1,
        children: [
          for (var week = 1; week <= table.totalWeeks; week++)
            Tappable(
              onPressed: () => onPick(week),
              shape: MiuixSquircleBorder(cornerRadius: 14),
              semanticLabel: '第 $week 周',
              child: Container(
                decoration: ShapeDecoration(
                  color: week == selected ? Brand.hero : palette.card,
                  shape: MiuixSquircleBorder(
                    cornerRadius: 14,
                    side: week == current && week != selected
                        ? BorderSide(color: Brand.accent, width: 1.5)
                        : BorderSide.none,
                  ),
                ),
                padding: const EdgeInsets.all(8),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$week',
                      style: TypeScale.card.copyWith(
                        color: week == selected
                            ? const Color(0xFFFFFFFF)
                            : palette.ink,
                      ),
                    ),
                    // Busy bar: share of the busiest week's course count.
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: SizedBox(
                        height: 4,
                        child: Stack(
                          children: [
                            Container(
                              color: week == selected
                                  ? const Color(0x38FFFFFF)
                                  : palette.ghostFill,
                            ),
                            FractionallySizedBox(
                              widthFactor: counts[week - 1] / busiest,
                              child: Container(
                                color: week == selected
                                    ? const Color(0xFFFFFFFF)
                                    : Brand.accent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

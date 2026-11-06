import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

import '../custom_event.dart';
import '../models.dart';
import '../plan.dart';
import '../reminders.dart';
import 'glass.dart';
import 'icons.dart';
import 'tokens.dart';

/// Which layers of the timetable are visible.
enum Layer { both, biao, li }

const layerLabels = ['课表 + 自学', '只看课表', '只看自学'];

/// Weekdays (1 = Monday) that get a column: weekends only when something
/// ever happens on them.
List<int> visibleWeekdays(Timetable timetable, List<PlanItem> plans) {
  bool used(int weekday) =>
      timetable.hasCoursesOn(weekday) ||
      plans.any((plan) => plan.scheduled && plan.date!.weekday == weekday);
  return [1, 2, 3, 4, 5, if (used(6) || used(7)) 6, if (used(6) || used(7)) 7];
}

/// The whole week on one screen: rows share the available height so all
/// periods fit without scrolling (down to a 40 dp floor).
class WeekGrid extends StatelessWidget {
  const WeekGrid({
    super.key,
    required this.timetable,
    required this.week,
    required this.layer,
    required this.plans,
    required this.showOtherWeeks,
    required this.now,
    this.onCourseTap,
    this.onPlanTap,
  });

  final Timetable timetable;
  final int week;
  final Layer layer;
  final List<PlanItem> plans;
  final bool showOtherWeeks;
  final DateTime now;
  final void Function(Course course, DateTime date)? onCourseTap;
  final void Function(PlanItem plan)? onPlanTap;

  static const _timeColumn = 36.0;
  static const _header = 42.0;
  static const _gap = 2.0;
  static const _minRow = 40.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final days = visibleWeekdays(timetable, plans);
        final periods = timetable.periodCount;
        final available = constraints.maxHeight - _header;
        final rowHeight = math.max(_minRow, available / periods);
        final columnWidth = (constraints.maxWidth - _timeColumn) / days.length;
        final height = _header + rowHeight * periods;
        final grid = SizedBox(
          width: constraints.maxWidth,
          height: height,
          child: Stack(
            children: _cells(context, days, periods, rowHeight, columnWidth),
          ),
        );
        return height <= constraints.maxHeight + 0.5
            ? grid
            : SingleChildScrollView(child: grid);
      },
    );
  }

  List<Widget> _cells(
    BuildContext context,
    List<int> days,
    int periods,
    double rowHeight,
    double columnWidth,
  ) {
    final palette = Palette(context);
    final today = dateOnly(now);
    double left(int weekday) =>
        _timeColumn + days.indexOf(weekday) * columnWidth;
    double top(int period) => _header + (period - 1) * rowHeight;
    final children = <Widget>[];

    // Day headers.
    for (final weekday in days) {
      final date = timetable.dateFor(week, weekday);
      final isToday = date != null && sameDate(date, today);
      children.add(
        Positioned(
          left: left(weekday) + _gap / 2,
          top: 2,
          width: columnWidth - _gap,
          height: _header - 6,
          child: Container(
            decoration: ShapeDecoration(
              color: isToday ? Brand.hero : const Color(0x00000000),
              shape: MiuixSquircleBorder(cornerRadius: 10),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  weekdayNames[weekday - 1],
                  style: TypeScale.caption.copyWith(
                    color: isToday ? const Color(0xFFFFFFFF) : palette.ink,
                  ),
                ),
                if (date != null)
                  Text(
                    '${date.month}/${date.day}',
                    style: TypeScale.caption.copyWith(
                      fontWeight: FontWeight.w400,
                      color: isToday
                          ? const Color(0xFFFFFFFF)
                          : palette.secondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    // Period labels.
    for (var period = 1; period <= periods; period++) {
      final start = periodStartTimes[period - 1];
      children.add(
        Positioned(
          left: 0,
          top: top(period),
          width: _timeColumn,
          height: rowHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '$period',
                style: TypeScale.caption.copyWith(color: palette.ink),
              ),
              if (rowHeight >= 44)
                Text(
                  '${start.$1}:${start.$2.toString().padLeft(2, '0')}',
                  style: TypeScale.caption.copyWith(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: palette.secondary,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    // Courses of this week, with overlapping ones split into lanes.
    final weekCourses = timetable
        .coursesForWeek(week)
        .where(
          (course) =>
              days.contains(course.weekday) && course.endPeriod <= periods,
        )
        .toList();
    final weekPlans = <PlanItem>[];
    for (final weekday in days) {
      final date = timetable.dateFor(week, weekday);
      if (date != null) weekPlans.addAll(plansForDate(plans, date));
    }

    Widget block({
      required int weekday,
      required int start,
      required int end,
      required Widget child,
      int lane = 0,
      int lanes = 1,
    }) {
      final laneWidth = (columnWidth - _gap) / lanes;
      return Positioned(
        left: left(weekday) + _gap / 2 + lane * laneWidth,
        top: top(start) + _gap / 2,
        width: laneWidth - (lanes > 1 ? _gap / 2 : 0),
        height: (end - start + 1) * rowHeight - _gap,
        child: child,
      );
    }

    if (layer != Layer.li) {
      // Ghosts of courses that meet in other weeks, where this week is free.
      if (showOtherWeeks) {
        final placed = <Course>[];
        for (final course in timetable.courses) {
          if (course.weeks.contains(week) ||
              !days.contains(course.weekday) ||
              course.endPeriod > periods) {
            continue;
          }
          bool overlaps(Course other) =>
              other.weekday == course.weekday &&
              other.startPeriod <= course.endPeriod &&
              other.endPeriod >= course.startPeriod;
          if (weekCourses.any(overlaps) || placed.any(overlaps)) continue;
          placed.add(course);
          final date = timetable.dateFor(week, course.weekday);
          children.add(
            block(
              weekday: course.weekday,
              start: course.startPeriod,
              end: course.endPeriod,
              child: _CourseBlock(
                title: course.name,
                subtitle: '非本周',
                fill: palette.ghostFill,
                ink: palette.ghostInk,
                onTap: date == null
                    ? null
                    : () => onCourseTap?.call(course, date),
              ),
            ),
          );
        }
      }

      for (final (course, lane, lanes) in _lanes(weekCourses)) {
        final (fill, ink) = CoursePalette.of(course.name, palette.dark);
        final date = timetable.dateFor(week, course.weekday);
        PlanItem? inner;
        if (layer == Layer.both && date != null) {
          for (final plan in weekPlans) {
            if (sameDate(plan.date!, date) &&
                plan.startPeriod! <= course.endPeriod &&
                plan.endPeriod! >= course.startPeriod) {
              inner = plan;
              break;
            }
          }
        }
        children.add(
          block(
            weekday: course.weekday,
            start: course.startPeriod,
            end: course.endPeriod,
            lane: lane,
            lanes: lanes,
            child: _CourseBlock(
              title: course.name,
              subtitle: course.room.isEmpty ? null : '@${course.room}',
              fill: fill,
              ink: ink,
              inner: inner?.title,
              innerDone: inner?.done ?? false,
              onTap: date == null
                  ? null
                  : () => onCourseTap?.call(course, date),
            ),
          ),
        );
      }
    }

    // 里课: on their own when only 里 is shown, or in free slots otherwise.
    if (layer != Layer.biao) {
      for (final plan in weekPlans) {
        if (plan.endPeriod! > periods || !days.contains(plan.date!.weekday)) {
          continue;
        }
        final under = weekCourses.where(
          (course) =>
              course.weekday == plan.date!.weekday &&
              course.startPeriod <= plan.endPeriod! &&
              course.endPeriod >= plan.startPeriod!,
        );
        if (layer == Layer.both && under.isNotEmpty) continue;
        children.add(
          block(
            weekday: plan.date!.weekday,
            start: plan.startPeriod!,
            end: plan.endPeriod!,
            child: _CourseBlock(
              title: plan.title,
              subtitle: under.isEmpty ? null : '原：${under.first.name}',
              fill: Brand.planFill(palette.dark),
              ink: Brand.planInk(palette.dark),
              dashed: under.isEmpty,
              done: plan.done,
              onTap: () => onPlanTap?.call(plan),
            ),
          ),
        );
      }
    }

    // Now line across today's column.
    final todayColumn = days.indexWhere((weekday) {
      final date = timetable.dateFor(week, weekday);
      return date != null && sameDate(date, today);
    });
    final y = _nowOffset(now, periods, rowHeight);
    if (todayColumn >= 0 && y != null) {
      children.add(
        Positioned(
          left: _timeColumn + todayColumn * columnWidth - 3,
          top: _header + y - 3,
          width: columnWidth + 3,
          height: 6,
          child: IgnorePointer(
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Brand.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                Expanded(child: Container(height: 2, color: Brand.accent)),
              ],
            ),
          ),
        ),
      );
    }
    return children;
  }

  /// Greedy lane assignment per weekday: overlapping courses sit side by side.
  static List<(Course, int, int)> _lanes(List<Course> courses) {
    final result = <(Course, int, int)>[];
    final byDay = <int, List<Course>>{};
    for (final course in courses) {
      byDay.putIfAbsent(course.weekday, () => []).add(course);
    }
    for (final list in byDay.values) {
      list.sort((a, b) => a.startPeriod.compareTo(b.startPeriod));
      var cluster = <Course>[];
      var clusterEnd = 0;
      void flush() {
        final laneEnds = <int>[];
        final assigned = <(Course, int)>[];
        for (final course in cluster) {
          var lane = laneEnds.indexWhere((end) => end < course.startPeriod);
          if (lane < 0) {
            lane = laneEnds.length;
            laneEnds.add(course.endPeriod);
          } else {
            laneEnds[lane] = course.endPeriod;
          }
          assigned.add((course, lane));
        }
        for (final (course, lane) in assigned) {
          result.add((course, lane, laneEnds.length));
        }
      }

      for (final course in list) {
        if (cluster.isNotEmpty && course.startPeriod > clusterEnd) {
          flush();
          cluster = [];
          clusterEnd = 0;
        }
        cluster.add(course);
        clusterEnd = math.max(clusterEnd, course.endPeriod);
      }
      if (cluster.isNotEmpty) flush();
    }
    return result;
  }

  /// Vertical offset of [now] within the period rows, or null outside them.
  static double? _nowOffset(DateTime now, int periods, double rowHeight) {
    final minutes = now.hour * 60 + now.minute + now.second / 60;
    for (var index = 0; index < periods; index++) {
      final start =
          periodStartTimes[index].$1 * 60 + periodStartTimes[index].$2;
      final next = index + 1 < periods
          ? periodStartTimes[index + 1].$1 * 60 + periodStartTimes[index + 1].$2
          : start + periodLengthMinutes;
      if (minutes >= start && minutes < next) {
        final fraction = ((minutes - start) / periodLengthMinutes).clamp(
          0.0,
          1.0,
        );
        return (index + fraction) * rowHeight;
      }
    }
    return null;
  }
}

class _CourseBlock extends StatelessWidget {
  const _CourseBlock({
    required this.title,
    required this.fill,
    required this.ink,
    this.subtitle,
    this.inner,
    this.innerDone = false,
    this.dashed = false,
    this.done = false,
    this.onTap,
  });

  final String title;
  final String? subtitle;
  final Color fill;
  final Color ink;
  final String? inner;
  final bool innerDone;
  final bool dashed;
  final bool done;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette(context);
    return Tappable(
      onPressed: onTap,
      feedbackType: MiuixPressFeedbackType.sink,
      shape: MiuixSquircleBorder(cornerRadius: 8),
      semanticLabel: [
        title,
        ?subtitle,
        if (inner != null) '自学 $inner',
      ].join('，'),
      child: Container(
        decoration: ShapeDecoration(
          color: fill,
          shape: MiuixSquircleBorder(
            cornerRadius: 8,
            side: dashed
                ? BorderSide(color: ink.withValues(alpha: 0.6), width: 1.2)
                : BorderSide.none,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(4, 4, 3, 3),
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Whole lines only, so nothing is clipped mid-glyph. The course
            // name comes first, then the room, then the inner self-study chip.
            const titleLine = 15.0;
            const subLine = 14.0;
            final titleStyle = TypeScale.caption.copyWith(
              fontSize: 12,
              height: titleLine / 12,
              color: ink,
              decoration: done ? TextDecoration.lineThrough : null,
            );
            int linesFor(String text) {
              final painter = TextPainter(
                text: TextSpan(text: text, style: titleStyle),
                textDirection: TextDirection.ltr,
                textScaler: MediaQuery.textScalerOf(context),
              )..layout(maxWidth: constraints.maxWidth);
              final lines = painter.computeLineMetrics().length;
              painter.dispose();
              return lines;
            }

            // A short suffix like the "A" in "高等数学 A" must not sit alone on
            // its own line: if it would cost an extra line, it moves to the
            // front of the room line instead ("A · @教 1-305").
            var shown = title;
            var sub = subtitle;
            var needed = linesFor(title);
            final suffix = RegExp(
              r'^(.*\S)\s+([A-Za-zⅠⅡⅢⅣ])$',
            ).firstMatch(title);
            if (suffix != null && !dashed) {
              final base = suffix[1]!;
              final baseLines = linesFor(base);
              if (baseLines < needed) {
                shown = base;
                needed = baseLines;
                sub = sub == null ? suffix[2] : '${suffix[2]} · $sub';
              }
            }
            var room = constraints.maxHeight;
            final titleLines = math
                .min(needed, (room / titleLine).floor())
                .clamp(1, 6);
            room -= titleLines * titleLine;
            final showInner = inner != null && room >= 30;
            if (showInner) room -= 30;
            final subLines = sub == null
                ? 0
                : ((room - 2) / subLine).floor().clamp(0, 2);
            final showSub = subLines > 0;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  shown,
                  maxLines: titleLines,
                  overflow: TextOverflow.ellipsis,
                  style: titleStyle,
                ),
                if (showSub)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      sub!,
                      maxLines: subLines,
                      overflow: TextOverflow.ellipsis,
                      style: TypeScale.caption.copyWith(
                        fontWeight: FontWeight.w400,
                        color: ink,
                      ),
                    ),
                  ),
                if (showInner) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.fromLTRB(3, 2, 3, 2),
                    decoration: ShapeDecoration(
                      // Finished study reads as done, not disabled.
                      color: innerDone ? palette.tint : Brand.hero,
                      shape: MiuixSquircleBorder(cornerRadius: 5),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 1, right: 2),
                          child: AppIcon(
                            innerDone ? AppIcons.check : AppIcons.study,
                            size: 12,
                            strokeWidth: 2,
                            color: innerDone
                                ? palette.accentText
                                : const Color(0xFFFFFFFF),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            inner!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TypeScale.caption.copyWith(
                              color: innerDone
                                  ? palette.accentText
                                  : const Color(0xFFFFFFFF),
                              decoration: innerDone
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else if (inner != null) ...[
                  const Spacer(),
                  Container(
                    height: 4,
                    width: 12,
                    decoration: ShapeDecoration(
                      color: Brand.hero,
                      shape: MiuixSquircleBorder(cornerRadius: 2),
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

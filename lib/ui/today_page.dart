import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

import '../custom_event.dart';
import '../models.dart';
import '../plan.dart';
import '../reminders.dart';
import 'actions.dart';
import 'common.dart';
import 'glass.dart';
import 'icons.dart';
import 'reflection_page.dart';
import 'sheets.dart';
import 'tokens.dart';

/// One row of today's agenda: a 表 course (maybe with a 里 plan inside), a
/// 里 plan in a free slot, or a custom event.
class _AgendaRow {
  _AgendaRow({
    required this.start,
    required this.end,
    this.course,
    this.plan,
    this.event,
  });

  final int start; // minutes since midnight
  final int end;
  final Course? course;
  final PlanItem? plan;
  final CustomEvent? event;

  String get title => course?.name ?? event?.title ?? plan!.title;
}

int _periodStart(int period) =>
    periodStartTimes[period - 1].$1 * 60 + periodStartTimes[period - 1].$2;
int _periodEnd(int period) => _periodStart(period) + periodLengthMinutes;

List<_AgendaRow> _agenda(
  Timetable? table,
  List<PlanItem> plans,
  List<CustomEvent> events,
  DateTime day,
) {
  final rows = <_AgendaRow>[];
  final dayPlans = plansForDate(plans, day);
  final used = <PlanItem>{};
  for (final course in table?.coursesForDate(day) ?? const <Course>[]) {
    PlanItem? inner;
    for (final plan in dayPlans) {
      if (plan.startPeriod! <= course.endPeriod &&
          plan.endPeriod! >= course.startPeriod) {
        inner = plan;
        used.add(plan);
        break;
      }
    }
    rows.add(
      _AgendaRow(
        start: _periodStart(course.startPeriod),
        end: _periodEnd(course.endPeriod),
        course: course,
        plan: inner,
      ),
    );
  }
  for (final plan in dayPlans) {
    if (used.contains(plan) || plan.endPeriod! > periodStartTimes.length) {
      continue;
    }
    rows.add(
      _AgendaRow(
        start: _periodStart(plan.startPeriod!),
        end: _periodEnd(plan.endPeriod!),
        plan: plan,
      ),
    );
  }
  for (final event in customEventsForDate(events, day)) {
    rows.add(
      _AgendaRow(
        start: event.startMinutes,
        end: event.endMinutes,
        event: event,
      ),
    );
  }
  return rows..sort((a, b) => a.start.compareTo(b.start));
}

class TodayPage extends StatefulWidget {
  const TodayPage({
    super.key,
    required this.onOpenWeek,
    required this.reselect,
  });

  final Reselect reselect;

  final VoidCallback onOpenWeek;

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  final _sheet = SheetController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.reselect.addListener(_toTop);
  }

  void _toTop() {
    if (!_scroll.hasClients) return;
    _scroll.animateTo(
      0,
      duration: const Duration(milliseconds: 360),
      curve: const Cubic(0.2, 0.8, 0.2, 1),
    );
  }

  @override
  void dispose() {
    widget.reselect.removeListener(_toTop);
    _scroll.dispose();
    _sheet.dispose();
    super.dispose();
  }

  void _openRow(_AgendaRow row, DateTime today) {
    if (row.course != null) {
      _sheet.open(CourseSheetRequest(row.course!, today));
    } else if (row.event != null) {
      _sheet.open(EventSheetRequest(event: row.event, date: today));
    } else {
      _sheet.open(PlanSheetRequest(row.plan!.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final palette = Palette(context);
    final now = DateTime.now();
    final today = dateOnly(now);
    final table = state.timetable;
    final rows = _agenda(table, state.plans, state.events, today);
    final courseCount = rows.where((row) => row.course != null).length;
    final planCount = rows.where((row) => row.plan != null).length;
    final eventCount = rows.where((row) => row.event != null).length;
    final meta = [
      if (table != null) weekText(table, today),
      dateLabel(today),
    ].join(' · ');

    return MiuixScaffold(
      containerColor: const Color(0x00000000),
      content: (padding) => Stack(
        children: [
          ListView(
            controller: _scroll,
            padding: EdgeInsets.only(
              top: padding.top,
              bottom: padding.bottom + 24,
            ),
            children: [
              PageHeader(
                title: '今天',
                meta: meta,
                trailing: RoundIconButton(
                  icon: AppIcons.calendarPlus,
                  label: '新建事件',
                  onPressed: () => _sheet.open(EventSheetRequest(date: today)),
                ),
              ),
              const SizedBox(height: 4),
              if (state.loading)
                const _LoadingSkeleton()
              else if (table == null)
                _ImportCard()
              else ...[
                _NowCard(rows: rows, table: table, events: state.events),
                SectionLabel(
                  icon: AppIcons.timetable,
                  rows.isEmpty
                      ? '今天没有安排'
                      : [
                          if (courseCount > 0) '$courseCount 门课',
                          if (planCount > 0) '$planCount 个自学',
                          if (eventCount > 0) '$eventCount 个事件',
                        ].join(' · '),
                ),
                if (rows.isNotEmpty)
                  PageCard(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        for (final row in rows)
                          _AgendaTile(
                            row: row,
                            now: now,
                            onTap: () => _openRow(row, today),
                          ),
                      ],
                    ),
                  )
                else
                  PageCard(
                    padding: const EdgeInsets.all(20),
                    onPressed: widget.onOpenWeek,
                    semanticLabel: '今天没有安排，去课表看看这周',
                    child: Row(
                      children: [
                        AppIcon(
                          AppIcons.coffee,
                          size: 32,
                          color: palette.accentText,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            '今天没有课，也没有自学和事件。点这里看整周课表。',
                            style: TypeScale.secondary.copyWith(
                              color: palette.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              const SizedBox(height: 12),
              _ReflectionCard(now: now),
            ],
          ),
          SheetLayer(controller: _sheet),
        ],
      ),
    );
  }
}

/// Placeholder shapes while stored data loads, so nothing jumps.
class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final palette = Palette(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Container(
            height: 150,
            decoration: ShapeDecoration(
              color: palette.tint,
              shape: MiuixSquircleBorder(cornerRadius: 24),
            ),
          ),
        ),
        const SizedBox(height: 44),
        const PageCard(child: SizedBox(height: 240, width: double.infinity)),
      ],
    );
  }
}

class _ImportCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = Palette(context);
    return PageCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(AppIcons.graduation, color: TileColors.orange, size: 44),
          const SizedBox(height: 14),
          Text('还没有课表', style: TypeScale.card.copyWith(color: palette.ink)),
          const SizedBox(height: 4),
          Text(
            '在易班或教务系统导出班级课表 .xls，一键导入，不需要学号。',
            style: TypeScale.secondary.copyWith(color: palette.secondary),
          ),
          const SizedBox(height: 16),
          PrimaryButton(
            text: '导入课表',
            icon: AppIcons.fileImport,
            onPressed: () => importTimetable(context),
          ),
        ],
      ),
    );
  }
}

/// The orange card at the top: what is on now, or what comes next. It ticks
/// on its own so the rest of the page does not rebuild every second.
class _NowCard extends StatefulWidget {
  const _NowCard({
    required this.rows,
    required this.table,
    required this.events,
  });

  final List<_AgendaRow> rows;
  final Timetable table;
  final List<CustomEvent> events;

  @override
  State<_NowCard> createState() => _NowCardState();
}

/// "还有 15 小时" far ahead; a live countdown only within the hour.
String _waitText(Duration wait) {
  if (wait.inMinutes >= 60) {
    final hours = wait.inMinutes / 60;
    return hours >= 24
        ? '还有 ${(hours / 24).floor()} 天'
        : '还有 ${hours.floor()} 小时';
  }
  return countdownText(wait);
}

/// 今天 / 明天 / 后天, or the weekday and date further out.
String _dayWord(DateTime date) {
  final today = dateOnly(DateTime.now());
  final days = dateOnly(date).difference(today).inDays;
  return switch (days) {
    0 => '今天',
    1 => '明天',
    2 => '后天',
    _ => '${date.month}/${date.day} ${weekdayNames[date.weekday - 1]}',
  };
}

class _NowCardState extends State<_NowCard> {
  late Timer _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _now.hour * 60 + _now.minute + _now.second / 60;
    _AgendaRow? current;
    _AgendaRow? next;
    for (final row in widget.rows) {
      if (minutes >= row.start && minutes < row.end) {
        current ??= row;
      } else if (row.start > minutes) {
        next ??= row;
      }
    }

    String badge;
    var badgeIcon = AppIcons.clock;
    String time;
    String title;
    String? place;
    PlanItem? inner;
    double? progress;
    String footerLeft;
    String footerRight;
    if (current != null || next != null) {
      final row = (current ?? next)!;
      title = row.course?.name ?? row.event?.title ?? row.plan!.title;
      place = row.course == null
          ? row.event?.location
          : [
              row.course!.room,
              row.course!.teacher,
            ].where((part) => part.isNotEmpty).join(' · ');
      // The chip names what is studied inside a class; a plan on its own
      // is already the title.
      inner = row.course != null || row.event != null ? row.plan : null;
      time = '${clockText(row.start)}–${clockText(row.end)}';
      final periods = row.course != null
          ? '第 ${row.course!.startPeriod}–${row.course!.endPeriod} 节'
          : row.plan != null
          ? '第 ${row.plan!.startPeriod}–${row.plan!.endPeriod} 节'
          : '事件';
      if (current != null) {
        badge = '$periods · 进行中';
        badgeIcon = AppIcons.play;
        progress = ((minutes - row.start) / (row.end - row.start)).clamp(
          0.0,
          1.0,
        );
        footerLeft = '已过 ${(minutes - row.start).floor()} 分钟';
        footerRight = '还剩 ${(row.end - minutes).ceil()} 分钟';
      } else {
        badge = '$periods · 下一节';
        badgeIcon = AppIcons.hourglass;
        final wait = Duration(seconds: ((row.start - minutes) * 60).round());
        footerLeft = '距离开始';
        footerRight = _waitText(wait);
      }
    } else {
      final upcoming = nextUp(widget.table, widget.events, _now);
      // Only say "today's classes are over" when there were some.
      final dayBadge = widget.rows.isEmpty ? '今天没课' : '今天的课都结束了';
      if (upcoming == null) {
        badge = dayBadge;
        badgeIcon = AppIcons.moon;
        title = '本学期没有更多课了';
        time = '';
        footerLeft = '';
        footerRight = '';
      } else {
        badge = dayBadge;
        badgeIcon = AppIcons.moon;
        title = upcoming.title;
        place = upcoming.location;
        time =
            '${_dayWord(upcoming.start)} '
            '${clockText(upcoming.start.hour * 60 + upcoming.start.minute)}';
        footerLeft = '下一项';
        footerRight = _waitText(upcoming.start.difference(_now));
      }
    }

    const white = Color(0xFFFFFFFF);
    final dim = const Color(0xFFFFFFFF).withValues(alpha: 0.94);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      // Glow on a plain rounded box: squircle shadows render as a hard band.
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Brand.hero.withValues(alpha: 0.18),
              blurRadius: 32,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: ShapeDecoration(
            color: Brand.hero,
            shape: MiuixSquircleBorder(cornerRadius: 24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 3,
                    ),
                    decoration: ShapeDecoration(
                      color: const Color(0x33000000),
                      shape: MiuixSquircleBorder(cornerRadius: 10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppIcon(
                          badgeIcon,
                          size: 14,
                          color: white,
                          strokeWidth: 2,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          badge,
                          style: TypeScale.chip.copyWith(color: white),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Text(time, style: TypeScale.secondary.copyWith(color: white)),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TypeScale.stat.copyWith(color: white, height: 32 / 24),
              ),
              if (place != null && place.isNotEmpty)
                Row(
                  children: [
                    AppIcon(AppIcons.pin, size: 14, color: dim),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        place,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TypeScale.secondary.copyWith(color: dim),
                      ),
                    ),
                  ],
                ),
              if (inner != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                  decoration: ShapeDecoration(
                    color: const Color(0x2EFFFFFF),
                    shape: MiuixSquircleBorder(cornerRadius: 12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: ShapeDecoration(
                          color: white,
                          shape: MiuixSquircleBorder(cornerRadius: 8),
                        ),
                        child: AppIcon(
                          AppIcons.study,
                          size: 17,
                          color: Brand.hero,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          inner.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TypeScale.time.copyWith(color: white),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              if (progress != null) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: SizedBox(
                    height: 6,
                    child: Stack(
                      children: [
                        Container(color: const Color(0x38FFFFFF)),
                        FractionallySizedBox(
                          widthFactor: progress,
                          child: Container(color: white),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (footerLeft.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      footerLeft,
                      style: TypeScale.secondary.copyWith(color: dim),
                    ),
                    const Spacer(),
                    AppIcon(AppIcons.hourglass, size: 14, color: white),
                    const SizedBox(width: 5),
                    Text(
                      footerRight,
                      style: TypeScale.secondary.copyWith(color: white),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AgendaTile extends StatelessWidget {
  const _AgendaTile({
    required this.row,
    required this.now,
    required this.onTap,
  });

  final _AgendaRow row;
  final DateTime now;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette(context);
    final minutes = now.hour * 60 + now.minute;
    final past = row.end <= minutes;
    final current = minutes >= row.start && minutes < row.end;
    final course = row.course;
    final event = row.event;
    final isFreePlan = course == null && event == null;

    final Color bar;
    final String title;
    final String period;
    final details = <(String, String)>[]; // (icon, text)
    if (course != null) {
      bar = CoursePalette.of(course.name, palette.dark).$2;
      title = course.name;
      period = '${course.startPeriod}–${course.endPeriod} 节';
      if (course.room.isNotEmpty) details.add((AppIcons.pin, course.room));
      if (course.teacher.isNotEmpty) {
        details.add((AppIcons.person, course.teacher));
      }
    } else if (event != null) {
      bar = palette.secondary;
      title = event.title;
      period = '事件';
      details.add((
        event.weekly ? AppIcons.repeat : AppIcons.calendarPlus,
        '${clockText(event.startMinutes)}–${clockText(event.endMinutes)}',
      ));
      if (event.location.isNotEmpty) {
        details.add((AppIcons.pin, event.location));
      }
    } else {
      bar = Brand.accent;
      title = row.plan!.title;
      period = '${row.plan!.startPeriod}–${row.plan!.endPeriod} 节';
      details.add((
        AppIcons.book,
        row.plan!.group.isNotEmpty ? row.plan!.group : '自学',
      ));
    }
    final titleColor = past ? palette.secondary : palette.ink;

    return Tappable(
      onPressed: onTap,
      semanticLabel: [
        clockText(row.start),
        if (isFreePlan) '自学',
        title,
        for (final (_, text) in details) text,
        if (!isFreePlan && row.plan != null) '自学 ${row.plan!.title}',
        if (current) '进行中',
      ].join('，'),
      shape: MiuixSquircleBorder(cornerRadius: 16),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: ShapeDecoration(
          color: current ? palette.tint : const Color(0x00000000),
          shape: MiuixSquircleBorder(cornerRadius: 16),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 48,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      clockText(row.start),
                      style: TypeScale.time.copyWith(color: titleColor),
                    ),
                    Text(
                      period,
                      style: TypeScale.caption.copyWith(
                        fontWeight: FontWeight.w400,
                        color: palette.secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // The color bar runs the full height of the row.
              Container(
                width: 4,
                decoration: ShapeDecoration(
                  color: past ? palette.ghostFill : bar,
                  shape: MiuixSquircleBorder(cornerRadius: 2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      children: [
                        if (isFreePlan) ...[
                          AppIcon(
                            row.plan!.done ? AppIcons.check : AppIcons.study,
                            size: 18,
                            color: palette.accentText,
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TypeScale.listTitle.copyWith(
                              color: isFreePlan
                                  ? palette.accentText
                                  : titleColor,
                              decoration: isFreePlan && row.plan!.done
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Wrap(
                      spacing: 12,
                      runSpacing: 2,
                      children: [
                        for (final (icon, text) in details)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AppIcon(icon, size: 14, color: palette.secondary),
                              const SizedBox(width: 4),
                              Text(
                                text,
                                style: TypeScale.secondary.copyWith(
                                  color: palette.secondary,
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                    if (!isFreePlan && row.plan != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: InnerPlanChip(
                          title: row.plan!.title,
                          done: row.plan!.done,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReflectionCard extends StatelessWidget {
  const _ReflectionCard({required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final palette = Palette(context);
    final evening = now.hour >= 12;
    final entry = state.journalFor(now);
    final written = evening ? entry.evening : entry.morning;
    final settings = state.reflection;
    final at = clockText(
      evening ? settings.eveningMinutes : settings.morningMinutes,
    );
    return PageCard(
      semanticLabel: '${evening ? '晚间' : '晨间'}一分钟',
      onPressed: () => Navigator.of(context).push(
        SlideRoute((_) => ReflectionPage(evening: evening), ambient: false),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: palette.tint,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: AppIcon(
              evening ? AppIcons.lotus : AppIcons.sun,
              size: 22,
              color: palette.accentText,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${evening ? '晚间' : '晨间'}一分钟${settings.enabled ? ' · $at' : ''}',
                  style: TypeScale.listTitle.copyWith(color: palette.ink),
                ),
                Text(
                  written.isNotEmpty
                      ? written
                      : (evening
                                ? settings.eveningPrompt
                                : settings.morningPrompt)
                            .replaceAll('\n', ''),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeScale.secondary.copyWith(color: palette.secondary),
                ),
              ],
            ),
          ),
          AppIcon(AppIcons.chevronRight, size: 18, color: palette.secondary),
        ],
      ),
    );
  }
}

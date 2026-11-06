import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

import '../app_state.dart';
import '../custom_event.dart';
import '../models.dart';
import '../plan.dart';
import 'actions.dart';
import 'common.dart';
import 'glass.dart';
import 'icons.dart';
import 'sheets.dart';
import 'tokens.dart';
import 'week_grid.dart';

/// The 里课表: a week of two-period slots on top, a backlog of study cards
/// below. Long-press a card and drop it on a slot.
class PlanPage extends StatefulWidget {
  const PlanPage({super.key, required this.reselect});

  final Reselect reselect;

  @override
  State<PlanPage> createState() => _PlanPageState();
}

class _PlanPageState extends State<PlanPage> {
  final _sheet = SheetController();
  final _title = TextEditingController();
  final _group = TextEditingController();
  int? _week;
  String? _groupFilter;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    widget.reselect.addListener(_toThisWeek);
  }

  void _toThisWeek() => setState(() => _week = null);

  @override
  void dispose() {
    widget.reselect.removeListener(_toThisWeek);
    _sheet.dispose();
    _title.dispose();
    _group.dispose();
    super.dispose();
  }

  List<String> _groups(List<PlanItem> plans) => {
    for (final plan in plans)
      if (plan.group.isNotEmpty) plan.group,
  }.toList()..sort();

  void _openAdd() {
    _title.clear();
    _group.text = _groupFilter ?? '';
    setState(() => _adding = true);
  }

  void _saveCards(AppState state) {
    final lines = _title.text
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    if (lines.isEmpty) return;
    final group = _group.text.trim();
    final stamp = DateTime.now().microsecondsSinceEpoch;
    state.savePlans([
      ...state.plans,
      for (var index = 0; index < lines.length; index++)
        PlanItem(id: '${stamp}_$index', title: lines[index], group: group),
    ]);
    setState(() {
      _adding = false;
      if (group.isNotEmpty) _groupFilter = group;
    });
    toast('已添加 ${lines.length} 张卡片');
  }

  /// Fills this week's open slots with backlog cards, preferring courses the
  /// user already studies through (their "水课"), then free daytime slots.
  void _autoArrange(
    AppState state,
    Timetable table,
    int week,
    List<PlanItem> backlog,
  ) {
    if (backlog.isEmpty) {
      toast('没有待排的卡片');
      return;
    }
    final waterCourses = <String>{};
    for (final plan in state.plans.where((plan) => plan.scheduled)) {
      for (final course in table.coursesForDate(plan.date!)) {
        if (course.startPeriod <= plan.endPeriod! &&
            course.endPeriod >= plan.startPeriod!) {
          waterCourses.add(course.name);
        }
      }
    }
    final today = dateOnly(DateTime.now());
    final water = <(DateTime, int)>[];
    final free = <(DateTime, int)>[];
    for (final weekday in visibleWeekdays(table, state.plans)) {
      final date = table.dateFor(week, weekday);
      if (date == null || date.isBefore(today)) continue;
      for (var start = 1; start <= 7; start += 2) {
        if (planAt(state.plans, date, start) != null ||
            planAt(state.plans, date, start + 1) != null) {
          continue;
        }
        final courses = table
            .coursesForDate(date)
            .where(
              (course) =>
                  course.startPeriod <= start + 1 && course.endPeriod >= start,
            );
        if (courses.isEmpty) {
          free.add((date, start));
        } else if (courses.every(
          (course) => waterCourses.contains(course.name),
        )) {
          water.add((date, start));
        }
      }
    }
    final slots = [...water, ...free];
    var placed = 0;
    final before = state.plans;
    var plans = [...state.plans];
    for (final card in backlog) {
      if (placed >= slots.length) break;
      final (date, start) = slots[placed++];
      plans = [
        for (final plan in plans)
          if (plan.id == card.id) plan.placed(date, start, start + 1) else plan,
      ];
    }
    if (placed == 0) {
      toast('这周没有空出来的格子了');
      return;
    }
    state.savePlans(plans);
    HapticFeedback.mediumImpact();
    appSnackbar.showSnackbar('已排进 $placed 张卡片', actionLabel: '撤销').then((
      result,
    ) {
      if (result == MiuixSnackbarResult.actionPerformed) {
        state.savePlans(before);
      }
    });
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
              const PageHeader(title: '自学'),
              PageCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '先导入课表，再把自学内容排进每一节课里。',
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
    final week = (_week ?? table.weekFor(DateTime.now())).clamp(
      1,
      table.totalWeeks,
    );
    final groups = _groups(state.plans);
    if (_groupFilter != null && !groups.contains(_groupFilter)) {
      _groupFilter = null;
    }
    final backlog = state.plans
        .where(
          (plan) =>
              !plan.scheduled &&
              (_groupFilter == null || plan.group == _groupFilter),
        )
        .toList();
    final weekPlans = state.plans.where((plan) {
      if (!plan.scheduled) return false;
      return table.rawWeekFor(plan.date!) == week;
    }).toList();

    return MiuixScaffold(
      containerColor: const Color(0x00000000),
      content: (padding) => Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: padding.top),
            child: Column(
              children: [
                PageHeader(
                  title: '自学',
                  meta:
                      '第 $week 周 · ${weekPlans.length} 个自学 · 已完成 ${weekPlans.where((plan) => plan.done).length}',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RoundIconButton(
                        icon: AppIcons.chevronLeft,
                        label: '上一周',
                        onPressed: week > 1
                            ? () => setState(() => _week = week - 1)
                            : null,
                      ),
                      const SizedBox(width: 4),
                      RoundIconButton(
                        icon: AppIcons.chevronRight,
                        label: '下一周',
                        onPressed: week < table.totalWeeks
                            ? () => setState(() => _week = week + 1)
                            : null,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(6, 0, 8, 8),
                    child: _SlotGrid(
                      table: table,
                      week: week,
                      plans: state.plans,
                      onDrop: (plan, date, start) =>
                          state.placePlan(plan, date, start, start + 1),
                      onPlanTap: (plan) =>
                          _sheet.open(PlanSheetRequest(plan.id)),
                      onCourseTap: (course, date) =>
                          _sheet.open(CourseSheetRequest(course, date)),
                    ),
                  ),
                ),
                _Backlog(
                  bottomInset: padding.bottom,
                  groups: groups,
                  filter: _groupFilter,
                  cards: backlog,
                  onFilter: (group) => setState(() => _groupFilter = group),
                  onAdd: _openAdd,
                  onAuto: () => _autoArrange(state, table, week, backlog),
                  onCardTap: (plan) => _sheet.open(PlanSheetRequest(plan.id)),
                ),
              ],
            ),
          ),
          SheetLayer(controller: _sheet),
          MiuixOverlayDialog(
            show: _adding,
            title: '添加自学卡片',
            summary: '一行一张，可以一次粘贴整份讲次列表',
            onDismissRequest: () => setState(() => _adding = false),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  controller: _group,
                  hint: '课程名，比如 MIT 16.01',
                  singleLine: true,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: _title,
                  hint: '第 1 讲：导论\n第 2 讲：静力学\nPSet 1',
                  minLines: 3,
                  maxLines: 8,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: SecondaryButton(
                        text: '取消',
                        onPressed: () => setState(() => _adding = false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: PrimaryButton(
                        text: '添加',
                        onPressed: () => _saveCards(state),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Days × two-period slots. Every slot is a drop target.
class _SlotGrid extends StatelessWidget {
  const _SlotGrid({
    required this.table,
    required this.week,
    required this.plans,
    required this.onDrop,
    required this.onPlanTap,
    required this.onCourseTap,
  });

  final Timetable table;
  final int week;
  final List<PlanItem> plans;
  final void Function(PlanItem plan, DateTime date, int start) onDrop;
  final ValueChanged<PlanItem> onPlanTap;
  final void Function(Course course, DateTime date) onCourseTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette(context);
    final days = visibleWeekdays(table, plans);
    final slots = (table.periodCount + 1) ~/ 2;
    final today = dateOnly(DateTime.now());
    return Column(
      children: [
        Row(
          children: [
            const SizedBox(width: 30),
            for (final weekday in days)
              Expanded(
                child: Builder(
                  builder: (context) {
                    final date = table.dateFor(week, weekday);
                    final isToday = date != null && sameDate(date, today);
                    return Text(
                      weekdayShort[weekday - 1],
                      textAlign: TextAlign.center,
                      style: TypeScale.caption.copyWith(
                        color: isToday ? palette.accentText : palette.secondary,
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Column(
            children: [
              for (var slot = 0; slot < slots; slot++)
                Expanded(
                  child: Row(
                    children: [
                      SizedBox(
                        width: 30,
                        child: Text(
                          '${slot * 2 + 1}–${slot * 2 + 2}',
                          textAlign: TextAlign.center,
                          style: TypeScale.caption.copyWith(
                            fontWeight: FontWeight.w400,
                            color: palette.secondary,
                          ),
                        ),
                      ),
                      for (final weekday in days)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(1.5),
                            child: _slot(context, weekday, slot * 2 + 1),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _slot(BuildContext context, int weekday, int start) {
    final palette = Palette(context);
    final date = table.dateFor(week, weekday);
    if (date == null) return const SizedBox.shrink();
    final plan = planAt(plans, date, start) ?? planAt(plans, date, start + 1);
    final courses = table
        .coursesForDate(date)
        .where(
          (course) =>
              course.startPeriod <= start + 1 && course.endPeriod >= start,
        );
    final course = courses.isEmpty ? null : courses.first;
    return DragTarget<PlanItem>(
      onWillAcceptWithDetails: (details) => details.data.id != plan?.id,
      onAcceptWithDetails: (details) {
        HapticFeedback.selectionClick();
        onDrop(details.data, date, start);
      },
      builder: (context, candidates, _) {
        final hovering = candidates.isNotEmpty;
        Widget content;
        if (plan != null) {
          content = LongPressDraggable<PlanItem>(
            onDragStarted: HapticFeedback.mediumImpact,
            data: plan,
            feedback: _DragFeedback(title: plan.title),
            childWhenDragging: _cell(
              context,
              fill: palette.ghostFill,
              ink: palette.ghostInk,
              title: course?.name ?? '',
            ),
            child: Tappable(
              onPressed: () => onPlanTap(plan),
              semanticLabel:
                  '${weekdayNames[weekday - 1]} 第 $start–${start + 1} 节 自学 ${plan.title}',
              shape: MiuixSquircleBorder(cornerRadius: 8),
              child: _cell(
                context,
                fill: Brand.planFill(palette.dark),
                ink: Brand.planInk(palette.dark),
                title: plan.title,
                subtitle: course?.name,
                done: plan.done,
                border: course == null
                    ? Brand.planInk(palette.dark).withValues(alpha: 0.6)
                    : null,
              ),
            ),
          );
        } else if (course != null) {
          content = Tappable(
            onPressed: () => onCourseTap(course, date),
            semanticLabel:
                '${weekdayNames[weekday - 1]} 第 $start–${start + 1} 节 ${course.name}',
            shape: MiuixSquircleBorder(cornerRadius: 8),
            child: _cell(
              context,
              fill: palette.dark
                  ? const Color(0x1FFFFFFF)
                  : const Color(0x0D1A1A1A),
              ink: palette.dark ? palette.secondary : const Color(0xFF55555A),
              title: course.name,
            ),
          );
        } else {
          content = _cell(
            context,
            fill: palette.dark
                ? const Color(0x0DFFFFFF)
                : const Color(0x4DFFFFFF),
            ink: palette.secondary,
            title: '',
            empty: true,
          );
        }
        return AnimatedScale(
          scale: hovering ? 1.06 : 1,
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 160),
          child: DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: ShapeDecoration(
              shape: MiuixSquircleBorder(
                cornerRadius: 8,
                side: hovering
                    ? BorderSide(color: Brand.accent, width: 2)
                    : BorderSide.none,
              ),
            ),
            child: content,
          ),
        );
      },
    );
  }

  Widget _cell(
    BuildContext context, {
    required Color fill,
    required Color ink,
    required String title,
    String? subtitle,
    bool done = false,
    Color? border,
    bool empty = false,
  }) {
    if (empty) {
      // A faint plus says "drop a card here".
      return Container(
        decoration: ShapeDecoration(
          color: fill,
          shape: MiuixSquircleBorder(cornerRadius: 8),
        ),
        alignment: Alignment.center,
        child: AppIcon(
          AppIcons.dashedPlus,
          size: 18,
          color: ink.withValues(alpha: 0.45),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 3, 3),
      decoration: ShapeDecoration(
        color: fill,
        shape: MiuixSquircleBorder(
          cornerRadius: 8,
          side: border == null
              ? BorderSide.none
              : BorderSide(color: border, width: 1),
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TypeScale.caption.copyWith(
                    color: ink,
                    decoration: done ? TextDecoration.lineThrough : null,
                  ),
                ),
              ),
              if (subtitle != null && constraints.maxHeight > 44)
                Text(
                  '原：$subtitle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TypeScale.caption.copyWith(
                    fontWeight: FontWeight.w400,
                    color: ink,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.05,
      child: Container(
        width: 120,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: ShapeDecoration(
          color: Brand.hero,
          shape: MiuixSquircleBorder(cornerRadius: 12),
          shadows: [
            BoxShadow(
              color: Brand.hero.withValues(alpha: 0.35),
              blurRadius: 30,
              offset: Offset(0, 14),
            ),
          ],
        ),
        child: DefaultTextStyle(
          style: const TextStyle(decoration: TextDecoration.none),
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TypeScale.chip.copyWith(color: const Color(0xFFFFFFFF)),
          ),
        ),
      ),
    );
  }
}

class _Backlog extends StatelessWidget {
  const _Backlog({
    required this.bottomInset,
    required this.groups,
    required this.filter,
    required this.cards,
    required this.onFilter,
    required this.onAdd,
    required this.onAuto,
    required this.onCardTap,
  });

  final double bottomInset;
  final List<String> groups;
  final String? filter;
  final List<PlanItem> cards;
  final ValueChanged<String?> onFilter;
  final VoidCallback onAdd;
  final VoidCallback onAuto;
  final ValueChanged<PlanItem> onCardTap;

  @override
  Widget build(BuildContext context) {
    final palette = Palette(context);
    Widget chip(String label, String? value) {
      final selected = filter == value;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Tappable(
          onPressed: () => onFilter(value),
          semanticLabel: label,
          shape: MiuixSquircleBorder(cornerRadius: 16),
          // 32 dp pill inside a 48 dp hit area.
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Container(
              height: 32,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: ShapeDecoration(
                color: selected ? palette.ink : palette.ghostFill,
                shape: MiuixSquircleBorder(cornerRadius: 16),
              ),
              child: Text(
                label,
                style: TypeScale.chip.copyWith(
                  color: selected ? palette.card : palette.ink,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      height: 250 + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: ShapeDecoration(
        // Denser than a card: the panel carries text over the gradient.
        color: palette.dark ? const Color(0xB828221E) : const Color(0xBFFFFFFF),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          side: BorderSide(
            color: palette.dark
                ? const Color(0x1AFFFFFF)
                : const Color(0xD9FFFFFF),
          ),
        ),
        shadows: [
          BoxShadow(
            color: palette.dark
                ? const Color(0x66000000)
                : const Color(0x145A280A),
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 8),
            child: Row(
              children: [
                AppIcon(AppIcons.inbox, size: 22, color: palette.ink),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '待排 · ${cards.length} 张',
                    style: TypeScale.card.copyWith(color: palette.ink),
                  ),
                ),
                GlassTextButton(
                  text: '自动排',
                  icon: AppIcons.wand,
                  onPressed: onAuto,
                  accent: true,
                ),
                const SizedBox(width: 8),
                RoundIconButton(
                  icon: AppIcons.plus,
                  label: '添加卡片',
                  onPressed: onAdd,
                ),
              ],
            ),
          ),
          SizedBox(
            height: 48,
            // The last 24 dp fade out, hinting that more chips scroll in.
            child: ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: (rect) => LinearGradient(
                colors: const [
                  Color(0xFFFFFFFF),
                  Color(0xFFFFFFFF),
                  Color(0x00FFFFFF),
                ],
                stops: [0, 1 - 24 / rect.width, 1],
              ).createShader(rect),
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  chip('全部', null),
                  for (final group in groups) chip(group, group),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: cards.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppIcon(
                            AppIcons.study,
                            size: 36,
                            color: palette.accentText,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '点右上角 + 添加卡片，比如把 MIT 16.01 的讲次一行一行贴进去。',
                            textAlign: TextAlign.center,
                            style: TypeScale.secondary.copyWith(
                              color: palette.secondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 8,
                          crossAxisSpacing: 8,
                          mainAxisExtent: 64,
                        ),
                    itemCount: cards.length,
                    itemBuilder: (context, index) {
                      final card = cards[index];
                      final tile = Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: ShapeDecoration(
                          color: palette.dark
                              ? const Color(0x14FFFFFF)
                              : const Color(0xB3FFFFFF),
                          shape: MiuixSquircleBorder(
                            cornerRadius: 16,
                            side: BorderSide(
                              color: palette.dark
                                  ? const Color(0x1AFFFFFF)
                                  : const Color(0xE6FFFFFF),
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Row(
                              children: [
                                AppIcon(
                                  AppIcons.study,
                                  size: 15,
                                  color: palette.accentText,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    card.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TypeScale.chip.copyWith(
                                      color: palette.ink,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              [
                                if (card.group.isNotEmpty) card.group,
                                if (card.deferCount > 0)
                                  '拖延 ${card.deferCount} 次',
                              ].join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TypeScale.caption.copyWith(
                                fontWeight: FontWeight.w400,
                                color: card.deferCount >= 3
                                    ? palette.colors.error
                                    : palette.secondary,
                              ),
                            ),
                          ],
                        ),
                      );
                      return LongPressDraggable<PlanItem>(
                        data: card,
                        onDragStarted: HapticFeedback.mediumImpact,
                        feedback: _DragFeedback(title: card.title),
                        childWhenDragging: Opacity(opacity: 0.35, child: tile),
                        child: Tappable(
                          onPressed: () => onCardTap(card),
                          semanticLabel: '自学卡片 ${card.title}，长按拖进格子',
                          shape: MiuixSquircleBorder(cornerRadius: 16),
                          child: tile,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

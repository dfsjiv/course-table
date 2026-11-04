import 'package:flutter/material.dart' show Material, MaterialType;
import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';

import '../custom_event.dart';
import '../models.dart';
import '../plan.dart';
import '../reminders.dart';
import 'common.dart';
import 'icons.dart';
import 'tokens.dart';

/// What a page's detail sheet should show.
sealed class SheetRequest {
  const SheetRequest();
}

class CourseSheetRequest extends SheetRequest {
  const CourseSheetRequest(this.course, this.date);
  final Course course;
  final DateTime date;
}

class PlanSheetRequest extends SheetRequest {
  const PlanSheetRequest(this.planId);
  final String planId;
}

class EventSheetRequest extends SheetRequest {
  const EventSheetRequest({this.event, required this.date});
  final CustomEvent? event;
  final DateTime date;
}

/// Opens and closes a page's detail sheet.
class SheetController extends ValueNotifier<SheetRequest?> {
  SheetController() : super(null);
  void open(SheetRequest request) => value = request;
  void close() => value = null;
}

/// Lives in a page's tree and renders the sheet [controller] asks for. The
/// last request is kept while the sheet animates out.
class SheetLayer extends StatefulWidget {
  const SheetLayer({super.key, required this.controller});
  final SheetController controller;

  @override
  State<SheetLayer> createState() => _SheetLayerState();
}

class _SheetLayerState extends State<SheetLayer> {
  SheetRequest? _last;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SheetRequest?>(
      valueListenable: widget.controller,
      builder: (context, request, _) {
        if (request != null) _last = request;
        final shown = _last;
        final title = switch (shown) {
          CourseSheetRequest(:final course) => course.name,
          PlanSheetRequest() => '自学',
          EventSheetRequest(:final event) => event == null ? '新建事件' : '编辑事件',
          null => null,
        };
        return MiuixOverlayBottomSheet(
          show: request != null,
          title: title,
          onDismissRequest: widget.controller.close,
          onDismissFinished: () => setState(() => _last = null),
          content: Material(
            type: MaterialType.transparency,
            child: SingleChildScrollView(
              child: switch (shown) {
                CourseSheetRequest(:final course, :final date) => _CourseSheet(
                  key: ValueKey(course),
                  course: course,
                  date: date,
                  close: widget.controller.close,
                ),
                PlanSheetRequest(:final planId) => _PlanSheet(
                  key: ValueKey(planId),
                  planId: planId,
                  close: widget.controller.close,
                ),
                EventSheetRequest(:final event, :final date) => EventEditor(
                  key: ValueKey(event?.id ?? 'new'),
                  event: event,
                  initialDate: date,
                  close: widget.controller.close,
                ),
                null => const SizedBox(height: 120),
              },
            ),
          ),
        );
      },
    );
  }
}

/// "1–8、10、12、14 周"
String weekRangesText(List<int> weeks) {
  if (weeks.isEmpty) return '';
  final sorted = [...weeks]..sort();
  final parts = <String>[];
  var start = sorted.first;
  var previous = start;
  void flush() => parts.add(start == previous ? '$start' : '$start–$previous');
  for (final week in sorted.skip(1)) {
    if (week == previous + 1) {
      previous = week;
      continue;
    }
    flush();
    start = previous = week;
  }
  flush();
  return '第 ${parts.join('、')} 周';
}

String periodRangeText(int start, int end) {
  final from = periodStartTimes[start - 1];
  final to = periodStartTimes[end - 1];
  final endMinutes = to.$1 * 60 + to.$2 + periodLengthMinutes;
  return '第 $start–$end 节 · ${clockText(from.$1 * 60 + from.$2)}–${clockText(endMinutes)}';
}

class _InfoLine extends StatelessWidget {
  const _InfoLine(this.icon, this.text);
  final String icon; // one of AppIcons
  final String text;

  @override
  Widget build(BuildContext context) {
    final palette = Palette(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          AppIcon(icon, size: 20, color: palette.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TypeScale.value.copyWith(color: palette.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseSheet extends StatelessWidget {
  const _CourseSheet({
    super.key,
    required this.course,
    required this.date,
    required this.close,
  });

  final Course course;
  final DateTime date;
  final VoidCallback close;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final palette = Palette(context);
    PlanItem? plan;
    for (
      var period = course.startPeriod;
      period <= course.endPeriod && plan == null;
      period++
    ) {
      plan = planAt(state.plans, date, period);
    }
    final backlog = state.plans.where((item) => !item.scheduled).toList();
    final thisWeek = state.timetable?.weekFor(date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InfoLine(
          'recent',
          '${weekdayNames[course.weekday - 1]} ${periodRangeText(course.startPeriod, course.endPeriod)}',
        ),
        if (course.room.isNotEmpty)
          _InfoLine(
            'location',
            [
              course.campus,
              course.room,
            ].where((part) => part.isNotEmpty).join(' '),
          ),
        if (course.teacher.isNotEmpty)
          _InfoLine(AppIcons.person, course.teacher),
        _InfoLine(
          'months',
          '${weekRangesText(course.weeks)}'
              '${thisWeek != null && !course.weeks.contains(thisWeek) ? '（本周没有）' : ''}',
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            AppIcon(AppIcons.study, size: 16, color: palette.secondary),
            const SizedBox(width: 6),
            Text(
              '在这节课里自学',
              style: TypeScale.section.copyWith(color: palette.secondary),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (plan != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: InnerPlanChip(title: plan.title, done: plan.done),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  text: plan.done ? '标为未完成' : '学完了',
                  icon: plan.done ? AppIcons.undo : AppIcons.check,
                  onPressed: () {
                    state.upsertPlan(plan!.copyWith(done: !plan.done));
                    close();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SecondaryButton(
                  text: '放回待排',
                  icon: AppIcons.inbox,
                  onPressed: () {
                    state.upsertPlan(plan!.unplaced());
                    close();
                  },
                ),
              ),
            ],
          ),
        ] else if (backlog.isEmpty)
          Text(
            '还没有待排的自学卡片。到「自学」页添加，比如「MIT 16.01 第 4 讲」。',
            style: TypeScale.secondary.copyWith(color: palette.secondary),
          )
        else ...[
          Text(
            '选一张卡片放进这节课：',
            style: TypeScale.secondary.copyWith(color: palette.secondary),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 240),
            child: ListView(
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              children: [
                for (final item in backlog)
                  MiuixBasicComponent(
                    insideMargin: const EdgeInsets.symmetric(vertical: 12),
                    title: item.title,
                    summary: item.group.isEmpty ? null : item.group,
                    endActions: [
                      AppIcon(
                        AppIcons.plus,
                        size: 20,
                        color: palette.accentText,
                      ),
                    ],
                    onClick: () {
                      state.placePlan(
                        item,
                        date,
                        course.startPeriod,
                        course.endPeriod,
                      );
                      close();
                    },
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _PlanSheet extends StatelessWidget {
  const _PlanSheet({super.key, required this.planId, required this.close});

  final String planId;
  final VoidCallback close;

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final palette = Palette(context);
    final matches = state.plans.where((item) => item.id == planId);
    if (matches.isEmpty) return const SizedBox(height: 120);
    final plan = matches.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(plan.title, style: TypeScale.card.copyWith(color: palette.ink)),
        if (plan.group.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              plan.group,
              style: TypeScale.secondary.copyWith(color: palette.secondary),
            ),
          ),
        const SizedBox(height: 8),
        if (plan.scheduled)
          _InfoLine(
            'recent',
            '${plan.date!.month} 月 ${plan.date!.day} 日 ${weekdayNames[plan.date!.weekday - 1]} · ${periodRangeText(plan.startPeriod!, plan.endPeriod!)}',
          ),
        if (plan.deferCount > 0)
          _InfoLine(AppIcons.undo, '已经放回待排 ${plan.deferCount} 次'),
        if (plan.note.isNotEmpty) _InfoLine(AppIcons.journal, plan.note),
        const SizedBox(height: 16),
        Row(
          children: [
            if (plan.scheduled) ...[
              Expanded(
                child: PrimaryButton(
                  text: plan.done ? '标为未完成' : '学完了',
                  icon: plan.done ? AppIcons.undo : AppIcons.check,
                  onPressed: () {
                    state.upsertPlan(plan.copyWith(done: !plan.done));
                    close();
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SecondaryButton(
                  text: '放回待排',
                  icon: AppIcons.inbox,
                  onPressed: () {
                    state.upsertPlan(plan.unplaced());
                    close();
                  },
                ),
              ),
            ] else
              Expanded(
                child: SecondaryButton(
                  text: '删除卡片',
                  icon: AppIcons.trash,
                  onPressed: () {
                    state.deletePlan(plan.id);
                    close();
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// Create or edit a custom event, inline in a bottom sheet.
class EventEditor extends StatefulWidget {
  const EventEditor({
    super.key,
    this.event,
    required this.initialDate,
    required this.close,
  });

  final CustomEvent? event;
  final DateTime initialDate;
  final VoidCallback close;

  @override
  State<EventEditor> createState() => _EventEditorState();
}

class _EventEditorState extends State<EventEditor> {
  late final _title = TextEditingController(text: widget.event?.title);
  late final _location = TextEditingController(text: widget.event?.location);
  late DateTime _date = widget.event?.date ?? widget.initialDate;
  late int _start = widget.event?.startMinutes ?? 8 * 60;
  late int _end = widget.event?.endMinutes ?? 9 * 60;
  late bool _weekly = widget.event?.weekly ?? false;
  late int _reminder = widget.event?.reminderMinutes ?? 15;
  String? _expanded; // 'date' | 'start' | 'end'
  String? _error;

  static const _reminders = [0, 5, 10, 15, 30, 60];

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    super.dispose();
  }

  void _toggle(String section) =>
      setState(() => _expanded = _expanded == section ? null : section);

  void _save() {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = '请填写名称');
      return;
    }
    if (_end <= _start) {
      setState(() => _error = '结束时间要晚于开始时间');
      return;
    }
    AppScope.read(context).upsertEvent(
      CustomEvent(
        id:
            widget.event?.id ??
            DateTime.now().microsecondsSinceEpoch.toString(),
        title: _title.text.trim(),
        location: _location.text.trim(),
        date: dateOnly(_date),
        startMinutes: _start,
        endMinutes: _end,
        weekly: _weekly,
        reminderMinutes: _reminder,
      ),
    );
    widget.close();
  }

  Widget _timePicker(int minutes, ValueChanged<int> onChanged) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 88,
          child: MiuixNumberPicker(
            value: minutes ~/ 60,
            min: 0,
            max: 23,
            visibleItemCount: 3,
            itemHeight: 40,
            wrapAround: true,
            textStyle: TypeScale.hero,
            label: (value) => value.toString().padLeft(2, '0'),
            onValueChanged: (hour) => onChanged(hour * 60 + minutes % 60),
          ),
        ),
        Text(':', style: TypeScale.hero),
        SizedBox(
          width: 88,
          child: MiuixNumberPicker(
            value: minutes % 60 ~/ 5,
            min: 0,
            max: 11,
            visibleItemCount: 3,
            itemHeight: 40,
            wrapAround: true,
            textStyle: TypeScale.hero,
            label: (value) => (value * 5).toString().padLeft(2, '0'),
            onValueChanged: (step) => onChanged(minutes ~/ 60 * 60 + step * 5),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = Palette(context);
    Widget value(String text) =>
        Text(text, style: TypeScale.value.copyWith(color: palette.secondary));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(controller: _title, hint: '名称，比如「社团例会」', singleLine: true),
        const SizedBox(height: 12),
        AppTextField(controller: _location, hint: '地点（可不填）', singleLine: true),
        const SizedBox(height: 8),
        MiuixArrowPreference(
          title: '日期',
          startAction: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AppIcon(
              AppIcons.calendarCheck,
              size: 22,
              color: palette.secondary,
            ),
          ),
          insideMargin: const EdgeInsets.symmetric(vertical: 14),
          endActions: [
            value(
              '${_date.month} 月 ${_date.day} 日 ${weekdayNames[_date.weekday - 1]}',
            ),
          ],
          onClick: () => _toggle('date'),
        ),
        if (_expanded == 'date')
          MiuixDatePicker(
            initialDate: _date,
            currentDate: DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime(2100),
            onDateChanged: (date) => setState(() => _date = date),
          ),
        MiuixArrowPreference(
          title: '开始',
          startAction: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AppIcon(AppIcons.clock, size: 22, color: palette.secondary),
          ),
          insideMargin: const EdgeInsets.symmetric(vertical: 14),
          endActions: [value(clockText(_start))],
          onClick: () => _toggle('start'),
        ),
        if (_expanded == 'start')
          _timePicker(_start, (minutes) => setState(() => _start = minutes)),
        MiuixArrowPreference(
          title: '结束',
          startAction: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AppIcon(
              AppIcons.hourglass,
              size: 22,
              color: palette.secondary,
            ),
          ),
          insideMargin: const EdgeInsets.symmetric(vertical: 14),
          endActions: [value(clockText(_end))],
          onClick: () => _toggle('end'),
        ),
        if (_expanded == 'end')
          _timePicker(_end, (minutes) => setState(() => _end = minutes)),
        MiuixSwitchPreference(
          title: '每周重复',
          startAction: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AppIcon(AppIcons.repeat, size: 22, color: palette.secondary),
          ),
          insideMargin: const EdgeInsets.symmetric(vertical: 14),
          value: _weekly,
          onChanged: (value) => setState(() => _weekly = value),
        ),
        MiuixOverlayDropdownPreference(
          title: '提醒',
          startAction: Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AppIcon(AppIcons.bell, size: 22, color: palette.secondary),
          ),
          insideMargin: const EdgeInsets.symmetric(vertical: 14),
          items: [
            for (final minutes in _reminders)
              minutes == 0 ? '不提醒' : '提前 $minutes 分钟',
          ],
          selectedIndex: _reminders
              .indexOf(_reminder)
              .clamp(0, _reminders.length - 1),
          onSelectedIndexChange: (index) =>
              setState(() => _reminder = _reminders[index]),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _error!,
              style: TypeScale.secondary.copyWith(color: palette.colors.error),
            ),
          ),
        const SizedBox(height: 16),
        Row(
          children: [
            if (widget.event != null) ...[
              Expanded(
                child: SecondaryButton(
                  text: '删除',
                  icon: AppIcons.trash,
                  onPressed: () {
                    AppScope.read(context).deleteEvent(widget.event!.id);
                    widget.close();
                  },
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: PrimaryButton(
                text: '保存',
                icon: AppIcons.check,
                onPressed: _save,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

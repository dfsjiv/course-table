import 'package:flutter/material.dart';

import 'custom_event.dart';

Future<CustomEvent?> showEventEditor(
  BuildContext context, {
  required DateTime initialDate,
  CustomEvent? event,
}) async {
  final title = TextEditingController(text: event?.title);
  final location = TextEditingController(text: event?.location);
  var date = event?.date ?? initialDate;
  var start = _timeFromMinutes(event?.startMinutes ?? 8 * 60);
  var end = _timeFromMinutes(event?.endMinutes ?? 9 * 60);
  var weekly = event?.weekly ?? false;
  var reminder = event?.reminderMinutes ?? 15;

  return showDialog<CustomEvent>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: Text(event == null ? '新建事件' : '编辑事件'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: title, decoration: const InputDecoration(labelText: '事情或课程名称')),
              TextField(controller: location, decoration: const InputDecoration(labelText: '地点')),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('日期'),
                subtitle: Text('${date.year}-${date.month}-${date.day}'),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    initialDate: date,
                  );
                  if (picked != null) setDialogState(() => date = picked);
                },
              ),
              Row(
                children: [
                  Expanded(child: _TimeTile(label: '开始', time: start, onChanged: (value) => setDialogState(() => start = value))),
                  Expanded(child: _TimeTile(label: '结束', time: end, onChanged: (value) => setDialogState(() => end = value))),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('每周重复'),
                value: weekly,
                onChanged: (value) => setDialogState(() => weekly = value),
              ),
              DropdownButtonFormField<int>(
                value: reminder,
                decoration: const InputDecoration(labelText: '提醒'),
                items: [0, 5, 10, 15, 30, 60]
                    .map((value) => DropdownMenuItem(value: value, child: Text(value == 0 ? '不提醒' : '提前$value分钟')))
                    .toList(),
                onChanged: (value) => setDialogState(() => reminder = value ?? 0),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(
            onPressed: () {
              final startMinutes = start.hour * 60 + start.minute;
              final endMinutes = end.hour * 60 + end.minute;
              if (title.text.trim().isEmpty || endMinutes <= startMinutes) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('请填写名称，并确保结束时间晚于开始时间')));
                return;
              }
              Navigator.pop(
                context,
                CustomEvent(
                  id: event?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
                  title: title.text.trim(),
                  location: location.text.trim(),
                  date: date,
                  startMinutes: startMinutes,
                  endMinutes: endMinutes,
                  weekly: weekly,
                  reminderMinutes: reminder,
                ),
              );
            },
            child: const Text('保存'),
          ),
        ],
      ),
    ),
  );
}

class _TimeTile extends StatelessWidget {
  const _TimeTile({required this.label, required this.time, required this.onChanged});
  final String label;
  final TimeOfDay time;
  final ValueChanged<TimeOfDay> onChanged;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: Text(time.format(context)),
        onTap: () async {
          final value = await showTimePicker(context: context, initialTime: time);
          if (value != null) onChanged(value);
        },
      );
}

TimeOfDay _timeFromMinutes(int minutes) =>
    TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);


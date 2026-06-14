import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'appearance.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.appearance, required this.onChanged});
  final AppearanceSettings appearance;
  final ValueChanged<AppearanceSettings> onChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late AppearanceSettings appearance = widget.appearance;

  void _update(AppearanceSettings value) {
    setState(() => appearance = value);
    widget.onChanged(value);
  }

  Future<void> _chooseBackground() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/course_table_background.jpg');
    await file.writeAsBytes(bytes, flush: true);
    _update(appearance.copyWith(backgroundPath: file.path));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: ListView(
        children: [
          const ListTile(title: Text('显示', style: TextStyle(fontWeight: FontWeight.bold))),
          for (final mode in ThemeMode.values)
            RadioListTile<ThemeMode>(
              value: mode,
              groupValue: appearance.themeMode,
              title: Text(switch (mode) {
                ThemeMode.system => '跟随系统',
                ThemeMode.light => '浅色模式',
                ThemeMode.dark => '深色模式',
              }),
              onChanged: (value) => _update(appearance.copyWith(themeMode: value)),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.image_outlined),
            title: const Text('选择背景图片'),
            subtitle: Text(appearance.backgroundPath == null ? '未设置' : '已设置'),
            onTap: _chooseBackground,
          ),
          if (appearance.backgroundPath != null)
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('移除背景图片'),
              onTap: () => _update(appearance.copyWith(removeBackground: true)),
            ),
          ListTile(
            title: const Text('背景可见度'),
            subtitle: Slider(
              value: appearance.backgroundOpacity,
              min: 0.05,
              max: 0.8,
              divisions: 15,
              label: '${(appearance.backgroundOpacity * 100).round()}%',
              onChanged: (value) => _update(appearance.copyWith(backgroundOpacity: value)),
            ),
          ),
        ],
      ),
    );
  }
}

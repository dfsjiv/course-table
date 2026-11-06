import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_miuix/miuix.dart';
import 'package:path_provider/path_provider.dart';

import '../app_state.dart';
import '../appearance.dart';
import '../island_controller.dart';
import '../notification_service.dart';
import '../plan.dart';
import '../theme_palette.dart';
import '../reminders.dart';
import '../platform_capabilities.dart';
import 'actions.dart';
import 'appearance_picker.dart';
import 'common.dart';
import 'icons.dart';
import 'schedule_page.dart';
import 'tokens.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.reselect});

  final Reselect reselect;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

enum _Dialog {
  none,
  startDate,
  morningTime,
  eveningTime,
  morningPrompt,
  eveningPrompt,
  island,
  palette,
  font,
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  final _island = IslandController();
  final _scroll = ScrollController();
  final _prompt = TextEditingController();
  final _paletteText = TextEditingController();
  String? _paletteName;
  String? _paletteError;
  bool _islandEnabled = false;
  IslandCapability? _capability;
  _Dialog _dialog = _Dialog.none;
  DateTime? _pickedDate;
  int _pickedMinutes = 0;

  static const _reminders = [0, 5, 10, 15, 30, 60];
  static const _themeModes = AppThemeMode.values;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    widget.reselect.addListener(_toTop);
    _refreshIslandStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.reselect.removeListener(_toTop);
    _scroll.dispose();
    _prompt.dispose();
    _paletteText.dispose();
    super.dispose();
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The focus-notification switch may have changed in system settings.
    if (state == AppLifecycleState.resumed) _refreshIslandStatus();
  }

  Future<void> _refreshIslandStatus() async {
    if (!supportsSystemIsland()) return;
    final enabled = await _island.isEnabled();
    final capability = await _island.capability();
    if (mounted) {
      setState(() {
        _islandEnabled = enabled;
        _capability = capability;
      });
    }
  }

  Future<void> _toggleIsland(bool value) async {
    if (!value) {
      await _island.stop();
      await _refreshIslandStatus();
      return;
    }
    await NotificationService().requestPermission();
    await _island.start();
    final capability = await _island.capability();
    await _refreshIslandStatus();
    if (capability == null || capability.hasFocusPermission || !mounted) return;
    setState(() => _dialog = _Dialog.island);
  }

  Future<void> _openSystemSettings(
    Future<bool> Function() open,
    String failure,
  ) async {
    if (!await open()) toast(failure);
  }

  Future<void> _chooseBackground(AppState state) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    final bytes = result?.files.single.bytes;
    if (bytes == null) return;
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/course_table_background.jpg');
    await file.writeAsBytes(bytes, flush: true);
    // A fresh path busts Image.file's cache when the picture changes.
    imageCache.evict(FileImage(file));
    await state.setAppearance(
      state.appearance.copyWith(backgroundPath: file.path),
    );
  }

  void _close() => setState(() => _dialog = _Dialog.none);

  void _openPaletteImport(AppState state) {
    final custom = state.appearance.customPalette;
    _paletteText.text = custom == null
        ? ''
        : const JsonEncoder.withIndent('  ').convert(custom.toJson());
    _paletteName = custom?.label;
    _paletteError = null;
    setState(() => _dialog = _Dialog.palette);
  }

  Future<void> _pickPaletteFile() async {
    final result = await FilePicker.platform.pickFiles(withData: true);
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    setState(() {
      _paletteText.text = utf8.decode(bytes, allowMalformed: true);
      _paletteName = file.name.replaceAll(RegExp(r'\.\w+$'), '');
      _paletteError = null;
    });
  }

  void _applyPalette(AppState state) {
    final palette = parsePalette(
      _paletteText.text,
      fallbackName: _paletteName ?? '导入的配色',
    );
    if (palette == null) {
      setState(
        () => _paletteError =
            '认不出这段配色。支持海纳 JSON、base16 / base24、VS Code 主题和 CSS 变量。',
      );
      return;
    }
    state.setAppearance(
      state.appearance.copyWith(
        customPalette: palette,
        paletteId: customPaletteId,
      ),
    );
    _close();
  }

  void _deletePalette(AppState state) {
    final appearance = state.appearance;
    state.setAppearance(
      appearance.copyWith(
        removeCustomPalette: true,
        paletteId: appearance.paletteId == customPaletteId
            ? defaultPaletteId
            : appearance.paletteId,
      ),
    );
    _close();
  }

  Future<void> _importFont(AppState state) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['ttf', 'otf', 'ttc'],
      withData: true,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null) return;
    final directory = await getApplicationDocumentsDirectory();
    final extension = (file.extension ?? 'ttf').toLowerCase();
    // A new name per import: the engine keeps a loaded family for good, so
    // reusing a name would keep showing the old font.
    final copy = File(
      '${directory.path}/font_${DateTime.now().millisecondsSinceEpoch}.$extension',
    );
    await copy.writeAsBytes(bytes, flush: true);
    final old = state.appearance.fontPath;
    final name = file.name.replaceAll(RegExp(r'\.\w+$'), '');
    final ok = await state.setAppearance(
      state.appearance.copyWith(fontPath: copy.path, fontName: name),
    );
    if (!ok) {
      await _deleteQuietly(copy.path);
      toast('这个文件读不出字体，换一个 .ttf / .otf 试试');
      return;
    }
    if (old != null) await _deleteQuietly(old);
    toast('字体已换成 $name');
  }

  Future<void> _resetFont(AppState state) async {
    final old = state.appearance.fontPath;
    await state.setAppearance(state.appearance.copyWith(removeFont: true));
    if (old != null) await _deleteQuietly(old);
  }

  static Future<void> _deleteQuietly(String path) async {
    try {
      await File(path).delete();
    } catch (_) {}
  }

  Widget _value(String text) => Text(
    text,
    style: TypeScale.value.copyWith(color: Palette(context).secondary),
  );

  Widget _timePicker() => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      SizedBox(
        width: 96,
        child: MiuixNumberPicker(
          value: _pickedMinutes ~/ 60,
          max: 23,
          wrapAround: true,
          label: (value) => value.toString().padLeft(2, '0'),
          onValueChanged: (hour) =>
              setState(() => _pickedMinutes = hour * 60 + _pickedMinutes % 60),
        ),
      ),
      Text(':', style: TypeScale.prompt),
      SizedBox(
        width: 96,
        child: MiuixNumberPicker(
          value: _pickedMinutes % 60 ~/ 5,
          max: 11,
          wrapAround: true,
          label: (value) => (value * 5).toString().padLeft(2, '0'),
          onValueChanged: (step) => setState(
            () => _pickedMinutes = _pickedMinutes ~/ 60 * 60 + step * 5,
          ),
        ),
      ),
    ],
  );

  Widget _dialogButtons(VoidCallback onSave) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Row(
      children: [
        Expanded(
          child: SecondaryButton(text: '取消', onPressed: _close),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: PrimaryButton(text: '确定', onPressed: onSave),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final palette = Palette(context);
    final table = state.timetable;
    final reflection = state.reflection;
    final appearance = state.appearance;

    final dialogTitle = switch (_dialog) {
      _Dialog.startDate => '开学日期',
      _Dialog.morningTime => '晨间提醒时间',
      _Dialog.eveningTime => '晚间提醒时间',
      _Dialog.morningPrompt => '晨间问题',
      _Dialog.eveningPrompt => '晚间问题',
      _Dialog.island => '让灵动岛生效',
      _Dialog.palette => '导入配色',
      _Dialog.font => '字体',
      _Dialog.none => null,
    };

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
              const PageHeader(title: '设置'),
              const SectionLabel('课表'),
              PageCard(
                child: Column(
                  children: [
                    MergeSemantics(
                      child: MiuixArrowPreference(
                        title: table == null ? '导入课表' : '重新导入课表',
                        startAction: const Padding(
                          padding: EdgeInsets.only(right: 14),
                          child: IconTile(
                            AppIcons.fileImport,
                            color: TileColors.orange,
                          ),
                        ),
                        summary: table == null
                            ? '易班 / 教务系统导出的 .xls'
                            : '${table.className.isEmpty ? '我的课表' : table.className} · ${table.courses.length} 门课',
                        onClick: () => importTimetable(context),
                      ),
                    ),
                    if (table != null) ...[
                      MergeSemantics(
                        child: MiuixArrowPreference(
                          title: '开学日期',
                          startAction: const Padding(
                            padding: EdgeInsets.only(right: 14),
                            child: IconTile(
                              AppIcons.calendarCheck,
                              color: TileColors.orange,
                            ),
                          ),
                          summary: '第 1 周的周一',
                          endActions: [
                            _value(
                              table.startDate == null
                                  ? '未设置'
                                  : '${table.startDate!.year}-${table.startDate!.month.toString().padLeft(2, '0')}-${table.startDate!.day.toString().padLeft(2, '0')}',
                            ),
                          ],
                          onClick: () => setState(() {
                            _pickedDate = table.startDate ?? DateTime.now();
                            _dialog = _Dialog.startDate;
                          }),
                        ),
                      ),
                      MergeSemantics(
                        child: MiuixArrowPreference(
                          title: '作息时间',
                          summary:
                              '${periodStartTimes.length} 节 · 每节 $periodLengthMinutes 分钟'
                              '${table.periodStarts == null ? '' : ' · 已自定义'}',
                          startAction: const Padding(
                            padding: EdgeInsets.only(right: 14),
                            child: IconTile(
                              AppIcons.clock,
                              color: TileColors.orange,
                            ),
                          ),
                          onClick: () => Navigator.of(
                            context,
                          ).push(SlideRoute((_) => const SchedulePage())),
                        ),
                      ),
                      MergeSemantics(
                        child: MiuixOverlayDropdownPreference(
                          title: '学期周数',
                          startAction: const Padding(
                            padding: EdgeInsets.only(right: 14),
                            child: IconTile(
                              AppIcons.layers,
                              color: TileColors.orange,
                            ),
                          ),
                          items: [
                            for (var weeks = 10; weeks <= 30; weeks++)
                              '$weeks 周',
                          ],
                          selectedIndex: (table.totalWeeks - 10).clamp(0, 20),
                          onSelectedIndexChange: (index) =>
                              state.updateSemester(totalWeeks: index + 10),
                        ),
                      ),
                      _SwitchRow(
                        title: '显示非本周课程',
                        startAction: const Padding(
                          padding: EdgeInsets.only(right: 14),
                          child: IconTile(
                            AppIcons.eye,
                            color: TileColors.orange,
                          ),
                        ),
                        summary: '整周课表里用灰色标出其他周才上的课',
                        value: state.showOtherWeeks,
                        onChanged: state.setShowOtherWeeks,
                      ),
                    ],
                  ],
                ),
              ),
              const SectionLabel('提醒'),
              PageCard(
                child: Column(
                  children: [
                    MergeSemantics(
                      child: MiuixOverlayDropdownPreference(
                        title: '课前提醒',
                        startAction: const Padding(
                          padding: EdgeInsets.only(right: 14),
                          child: IconTile(
                            AppIcons.bell,
                            color: TileColors.blue,
                          ),
                        ),
                        items: [
                          for (final minutes in _reminders)
                            minutes == 0 ? '关闭' : '提前 $minutes 分钟',
                        ],
                        selectedIndex: _reminders
                            .indexOf(state.reminderMinutes)
                            .clamp(0, _reminders.length - 1),
                        summary: table != null && table.startDate == null
                            ? '先设置开学日期，才知道哪周上哪些课'
                            : null,
                        onSelectedIndexChange: (index) =>
                            state.setReminderMinutes(_reminders[index]),
                      ),
                    ),
                    _SwitchRow(
                      title: '晨间 / 晚间一分钟',
                      startAction: const Padding(
                        padding: EdgeInsets.only(right: 14),
                        child: IconTile(
                          AppIcons.lotus,
                          color: TileColors.purple,
                        ),
                      ),
                      summary: '每天推送，点开花一分钟想想今天',
                      value: reflection.enabled,
                      onChanged: (value) => state.setReflection(
                        reflection.copyWith(enabled: value),
                      ),
                    ),
                    if (reflection.enabled) ...[
                      MergeSemantics(
                        child: MiuixArrowPreference(
                          title: '晨间时间',
                          startAction: const Padding(
                            padding: EdgeInsets.only(right: 14),
                            child: IconTile(
                              AppIcons.sun,
                              color: TileColors.purple,
                            ),
                          ),
                          endActions: [
                            _value(clockText(reflection.morningMinutes)),
                          ],
                          onClick: () => setState(() {
                            _pickedMinutes = reflection.morningMinutes;
                            _dialog = _Dialog.morningTime;
                          }),
                        ),
                      ),
                      MergeSemantics(
                        child: MiuixArrowPreference(
                          title: '晚间时间',
                          startAction: const Padding(
                            padding: EdgeInsets.only(right: 14),
                            child: IconTile(
                              AppIcons.moon,
                              color: TileColors.purple,
                            ),
                          ),
                          endActions: [
                            _value(clockText(reflection.eveningMinutes)),
                          ],
                          onClick: () => setState(() {
                            _pickedMinutes = reflection.eveningMinutes;
                            _dialog = _Dialog.eveningTime;
                          }),
                        ),
                      ),
                    ],
                    MergeSemantics(
                      child: MiuixArrowPreference(
                        title: '晨间问题',
                        startAction: const Padding(
                          padding: EdgeInsets.only(right: 14),
                          child: IconTile(
                            AppIcons.journal,
                            color: TileColors.purple,
                          ),
                        ),
                        summary: reflection.morningPrompt.replaceAll('\n', ' '),
                        onClick: () => setState(() {
                          _prompt.text = reflection.morningPrompt;
                          _dialog = _Dialog.morningPrompt;
                        }),
                      ),
                    ),
                    MergeSemantics(
                      child: MiuixArrowPreference(
                        title: '晚间问题',
                        startAction: const Padding(
                          padding: EdgeInsets.only(right: 14),
                          child: IconTile(
                            AppIcons.journal,
                            color: TileColors.purple,
                          ),
                        ),
                        summary: reflection.eveningPrompt.replaceAll('\n', ' '),
                        onClick: () => setState(() {
                          _prompt.text = reflection.eveningPrompt;
                          _dialog = _Dialog.eveningPrompt;
                        }),
                      ),
                    ),
                  ],
                ),
              ),
              if (supportsSystemIsland()) ...[
                const SectionLabel('超级岛'),
                PageCard(
                  child: Column(
                    children: [
                      _SwitchRow(
                        title: '系统超级岛',
                        startAction: const Padding(
                          padding: EdgeInsets.only(right: 14),
                          child: IconTile(
                            AppIcons.island,
                            color: TileColors.teal,
                          ),
                        ),
                        summary: table != null && table.startDate == null
                            ? '先设置开学日期，才知道哪周上哪些课'
                            : !_islandEnabled
                            ? '上课和课前显示在小米超级岛 / 焦点通知'
                            : (_capability?.description ?? '运行中'),
                        value: _islandEnabled,
                        onChanged: _toggleIsland,
                      ),
                      if (_islandEnabled &&
                          _capability != null &&
                          !_capability!.hasFocusPermission)
                        MergeSemantics(
                          child: MiuixArrowPreference(
                            title: '打开通知设置',
                            startAction: const Padding(
                              padding: EdgeInsets.only(right: 14),
                              child: IconTile(
                                AppIcons.bell,
                                color: TileColors.teal,
                              ),
                            ),
                            summary: '开启焦点通知权限后才会显示超级岛',
                            onClick: () => _openSystemSettings(
                              _island.openNotificationSettings,
                              '无法打开通知设置',
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
              const SectionLabel('外观'),
              PageCard(
                child: Column(
                  children: [
                    MergeSemantics(
                      child: MiuixOverlayDropdownPreference(
                        title: '深浅模式',
                        startAction: const Padding(
                          padding: EdgeInsets.only(right: 14),
                          child: IconTile(
                            AppIcons.moon,
                            color: TileColors.slate,
                          ),
                        ),
                        items: const ['跟随系统', '浅色', '深色'],
                        selectedIndex: _themeModes.indexOf(
                          appearance.themeMode,
                        ),
                        onSelectedIndexChange: (index) => state.setAppearance(
                          appearance.copyWith(themeMode: _themeModes[index]),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '配色',
                          style: TypeScale.section.copyWith(
                            color: palette.secondary,
                          ),
                        ),
                      ),
                    ),
                    PaletteGrid(
                      appearance: appearance,
                      onPick: (id) => state.setAppearance(
                        appearance.copyWith(paletteId: id),
                      ),
                      onImport: () => _openPaletteImport(state),
                    ),
                    MergeSemantics(
                      child: MiuixArrowPreference(
                        title: '字体',
                        startAction: const Padding(
                          padding: EdgeInsets.only(right: 14),
                          child: IconTile(
                            AppIcons.journal,
                            color: TileColors.slate,
                          ),
                        ),
                        summary: '支持导入 .ttf / .otf',
                        endActions: [_value(appearance.fontName ?? '系统默认')],
                        onClick: () => setState(() => _dialog = _Dialog.font),
                      ),
                    ),
                    MergeSemantics(
                      child: MiuixArrowPreference(
                        title: '背景图片',
                        startAction: const Padding(
                          padding: EdgeInsets.only(right: 14),
                          child: IconTile(
                            AppIcons.image,
                            color: TileColors.pink,
                          ),
                        ),
                        endActions: [
                          _value(
                            appearance.backgroundPath == null ? '未设置' : '已设置',
                          ),
                        ],
                        onClick: () => _chooseBackground(state),
                      ),
                    ),
                    if (appearance.backgroundPath != null) ...[
                      MergeSemantics(
                        child: MiuixSliderPreference(
                          title: '背景可见度',
                          startAction: const Padding(
                            padding: EdgeInsets.only(right: 14),
                            child: IconTile(
                              AppIcons.eye,
                              color: TileColors.pink,
                            ),
                          ),
                          valueText:
                              '${(appearance.backgroundOpacity * 100).round()}%',
                          value: appearance.backgroundOpacity,
                          min: 0.05,
                          max: 0.8,
                          onValueChange: (value) => state.setAppearance(
                            appearance.copyWith(backgroundOpacity: value),
                          ),
                        ),
                      ),
                      MergeSemantics(
                        child: MiuixArrowPreference(
                          title: '移除背景图片',
                          startAction: const Padding(
                            padding: EdgeInsets.only(right: 14),
                            child: IconTile(
                              AppIcons.trash,
                              color: TileColors.pink,
                            ),
                          ),
                          titleColor: MiuixBasicComponentColors(
                            color: palette.colors.error,
                            disabledColor: palette.colors.disabledOnSurface,
                          ),
                          onClick: () => state.setAppearance(
                            appearance.copyWith(removeBackground: true),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SectionLabel('日志'),
              PageCard(
                child: MiuixArrowPreference(
                  title: '每日日志',
                  startAction: const Padding(
                    padding: EdgeInsets.only(right: 14),
                    child: IconTile(AppIcons.journal, color: TileColors.amber),
                  ),
                  summary: state.journal.isEmpty
                      ? '晨间和晚间写下的话会存在这里'
                      : '已写 ${state.journal.length} 天',
                  onClick: () => Navigator.of(
                    context,
                  ).push(SlideRoute((_) => const JournalPage())),
                ),
              ),
              const SectionLabel('关于'),
              PageCard(
                child: Column(
                  children: [
                    MergeSemantics(
                      child: MiuixBasicComponent(
                        title: '版本',
                        startAction: const Padding(
                          padding: EdgeInsets.only(right: 14),
                          child: IconTile(
                            AppIcons.info,
                            color: TileColors.slate,
                          ),
                        ),
                        endActions: [_value('0.2.0')],
                      ),
                    ),
                    MergeSemantics(
                      child: MiuixBasicComponent(
                        title: '开源协议',
                        startAction: const Padding(
                          padding: EdgeInsets.only(right: 14),
                          child: IconTile(
                            AppIcons.shield,
                            color: TileColors.slate,
                          ),
                        ),
                        summary: 'GPL-3.0 · 界面基于 flutter_miuix（Apache-2.0）',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          MiuixOverlayDialog(
            show: _dialog != _Dialog.none,
            title: dialogTitle,
            summary: switch (_dialog) {
              _Dialog.island => _capability?.description,
              _Dialog.palette =>
                '海纳 JSON · base16 / base24 · VS Code 主题 · CSS 变量',
              _ => null,
            },
            onDismissRequest: _close,
            content: switch (_dialog) {
              _Dialog.startDate => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MiuixDatePicker(
                    initialDate: _pickedDate,
                    currentDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                    onDateChanged: (date) => setState(() => _pickedDate = date),
                  ),
                  _dialogButtons(() {
                    final date = _pickedDate!;
                    // Week 1 always starts on the Monday of the chosen week.
                    final monday = DateTime(
                      date.year,
                      date.month,
                      date.day - (date.weekday - 1),
                    );
                    state.updateSemester(startDate: monday);
                    _close();
                  }),
                ],
              ),
              _Dialog.morningTime || _Dialog.eveningTime => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _timePicker(),
                  _dialogButtons(() {
                    state.setReflection(
                      _dialog == _Dialog.morningTime
                          ? reflection.copyWith(morningMinutes: _pickedMinutes)
                          : reflection.copyWith(eveningMinutes: _pickedMinutes),
                    );
                    _close();
                  }),
                ],
              ),
              _Dialog.morningPrompt || _Dialog.eveningPrompt => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: _prompt,
                    hint: '写下想问自己的问题',
                    minLines: 2,
                    maxLines: 4,
                  ),
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: MiuixTextButton(
                      '恢复默认',
                      onPressed: () {
                        _prompt.text = _dialog == _Dialog.morningPrompt
                            ? ReflectionSettings.defaultMorningPrompt
                            : ReflectionSettings.defaultEveningPrompt;
                      },
                    ),
                  ),
                  _dialogButtons(() {
                    final text = _prompt.text.trim();
                    if (text.isEmpty) return;
                    state.setReflection(
                      _dialog == _Dialog.morningPrompt
                          ? reflection.copyWith(morningPrompt: text)
                          : reflection.copyWith(eveningPrompt: text),
                    );
                    _close();
                  }),
                ],
              ),
              _Dialog.island => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '想要显示成超级岛，需要在系统里：\n'
                    '· 允许 CourseTable 发送通知\n'
                    '· 在「通知管理」里打开焦点通知\n'
                    '· 允许自启动，省电策略设为「无限制」\n\n'
                    '焦点通知需要小米开通白名单，未开通时会显示成普通通知。',
                    style: TypeScale.value.copyWith(
                      color: palette.ink,
                      height: 22 / 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  PrimaryButton(
                    text: '打开通知设置',
                    onPressed: () {
                      _close();
                      _openSystemSettings(
                        _island.openNotificationSettings,
                        '无法打开通知设置',
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  SecondaryButton(
                    text: '开启自启动',
                    onPressed: () {
                      _close();
                      _openSystemSettings(
                        _island.openAutostartSettings,
                        '无法打开自启动设置，请到系统设置里手动允许',
                      );
                    },
                  ),
                ],
              ),
              _Dialog.palette => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppTextField(
                    controller: _paletteText,
                    hint: paletteExample,
                    minLines: 6,
                    maxLines: 10,
                    textStyle: TextStyle(
                      color: palette.ink,
                      fontFamily: 'monospace',
                    ),
                  ),
                  if (_paletteError != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _paletteError!,
                        style: TypeScale.secondary.copyWith(
                          color: palette.colors.error,
                        ),
                      ),
                    ),
                  const SizedBox(height: 10),
                  SecondaryButton(
                    text: '从文件读取',
                    icon: AppIcons.fileImport,
                    onPressed: _pickPaletteFile,
                  ),
                  if (appearance.customPalette != null) ...[
                    const SizedBox(height: 10),
                    MiuixTextButton(
                      '删除导入的配色',
                      onPressed: () => _deletePalette(state),
                    ),
                  ],
                  _dialogButtons(() => _applyPalette(state)),
                ],
              ),
              _Dialog.font => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '课表 Course 0123\n马克思主义基本原理 · 第 3–4 节',
                    textAlign: TextAlign.center,
                    style: TypeScale.body.copyWith(color: palette.ink),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '当前：${appearance.fontName ?? '系统默认'}。'
                    '建议选中文字体（比如更纱黑体、霞鹜文楷）；只含英文的字体，中文会用系统字体显示。',
                    style: TypeScale.secondary.copyWith(
                      color: palette.secondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  PrimaryButton(
                    text: '导入字体文件',
                    icon: AppIcons.fileImport,
                    onPressed: () {
                      _close();
                      _importFont(state);
                    },
                  ),
                  if (appearance.fontPath != null) ...[
                    const SizedBox(height: 10),
                    SecondaryButton(
                      text: '恢复系统字体',
                      onPressed: () {
                        _close();
                        _resetFont(state);
                      },
                    ),
                  ],
                  const SizedBox(height: 10),
                  SecondaryButton(text: '关闭', onPressed: _close),
                ],
              ),
              _Dialog.none => const SizedBox(height: 80),
            },
          ),
        ],
      ),
    );
  }
}

/// Past morning and evening reflections, newest first.
class JournalPage extends StatelessWidget {
  const JournalPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final palette = Palette(context);
    return MiuixScaffold(
      containerColor: const Color(0x00000000),
      topBar: MiuixSmallTopAppBar(
        title: '每日日志',
        color: const Color(0x00000000),
        navigationIcon: RoundIconButton(
          icon: AppIcons.back,
          label: '返回',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      content: (padding) => state.journal.isEmpty
          ? Center(
              child: Text(
                '还没有日志。早晚各花一分钟写一句吧。',
                style: TypeScale.secondary.copyWith(color: palette.secondary),
              ),
            )
          : ListView(
              padding: padding.copyWith(bottom: padding.bottom + 24),
              children: [
                for (final entry in state.journal) ...[
                  SectionLabel(dateLabel(entry.date)),
                  PageCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (entry.morning.isNotEmpty) ...[
                          Row(
                            children: [
                              AppIcon(
                                AppIcons.sunrise,
                                size: 16,
                                color: palette.accentText,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '晨间',
                                style: TypeScale.chip.copyWith(
                                  color: palette.accentText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.morning,
                            style: TypeScale.body.copyWith(color: palette.ink),
                          ),
                        ],
                        if (entry.morning.isNotEmpty &&
                            entry.evening.isNotEmpty)
                          const SizedBox(height: 12),
                        if (entry.evening.isNotEmpty) ...[
                          Row(
                            children: [
                              AppIcon(
                                AppIcons.moon,
                                size: 16,
                                color: palette.accentText,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                '晚间',
                                style: TypeScale.chip.copyWith(
                                  color: palette.accentText,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            entry.evening,
                            style: TypeScale.body.copyWith(color: palette.ink),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

/// A switch row whose small miuix switch merges into the full-height row,
/// so the whole 56 dp row is the touch target.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.title,
    required this.value,
    required this.onChanged,
    this.summary,
    this.startAction,
  });

  final String title;
  final String? summary;
  final bool value;
  final ValueChanged<bool> onChanged;
  final Widget? startAction;

  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: MiuixSwitchPreference(
      title: title,
      summary: summary,
      value: value,
      onChanged: onChanged,
      startAction: startAction,
    ),
  );
}

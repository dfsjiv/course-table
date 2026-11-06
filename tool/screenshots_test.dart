// ignore_for_file: invalid_use_of_visible_for_testing_member
// Renders every main screen to PNG for visual review:
//   flutter test tool/screenshots_test.dart --update-goldens
// Images land in tool/screenshots/. Needs Source Han Sans CN installed at
// /usr/share/fonts/adobe-source-han-sans-cn-fonts (any CJK font works if the
// path is changed).
import 'dart:io';

import 'package:course_table/app_state.dart';
import 'package:course_table/appearance.dart';
import 'package:course_table/main.dart';
import 'package:course_table/models.dart';
import 'package:course_table/plan.dart';
import 'package:course_table/theme_palette.dart';
import 'package:course_table/ui/reflection_page.dart';
import 'package:course_table/ui/common.dart';
import 'package:course_table/ui/schedule_page.dart';
import 'package:course_table/ui/semester_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _fontDir = '/usr/share/fonts/adobe-source-han-sans-cn-fonts';
final _miSans =
    '${Platform.environment['HOME']}/.pub-cache/hosted/pub.dev/flutter_miuix-1.3.0/example/fonts/MiSans-Normal.ttf';

Future<void> _loadFonts() async {
  for (final family in ['Roboto', '']) {
    final loader = FontLoader(family);
    // MiSans (the Xiaomi system font) for Latin and the CJK it covers,
    // Source Han Sans as the fallback for anything else.
    for (final path in [_miSans, '$_fontDir/SourceHanSansCN-Regular.otf']) {
      final bytes = File(path).readAsBytesSync();
      loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    }
    await loader.load();
  }
}

Course _course(
  String name,
  int weekday,
  int start,
  int end,
  String room,
  String teacher, {
  List<int>? weeks,
}) => Course(
  name: name,
  weekday: weekday,
  startPeriod: start,
  endPeriod: end,
  weeks: weeks ?? [for (var week = 1; week <= 16; week++) week],
  campus: '',
  room: room,
  teacher: teacher,
);

AppState _state(DateTime now, {bool dark = false, String? palette}) {
  final monday = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  final start = monday.subtract(const Duration(days: 7 * 6));
  final today = DateTime(now.year, now.month, now.day);
  final state = AppState()
    ..loading = false
    ..appearance = AppearanceSettings(
      themeMode: dark ? AppThemeMode.dark : AppThemeMode.light,
      paletteId: palette ?? defaultPaletteId,
    )
    ..timetable = Timetable(
      semester: '2026-2027年第1学期',
      className: '计科 2401',
      startDate: start,
      totalWeeks: 18,
      courses: [
        _course('高等数学 A', 1, 1, 2, '教 1-305', '王老师'),
        _course('大学英语', 1, 5, 6, '外语楼 204', '陈老师'),
        _course('数据结构', 2, 3, 4, '实训楼北 306', '赵老师'),
        _course('体育', 2, 7, 8, '东操场', '孙老师'),
        _course('高等数学 A', 3, 1, 2, '教 1-305', '王老师'),
        _course('马克思主义基本原理', 3, 5, 6, '教 3-201', '李老师'),
        _course('高等数学 A', 4, 1, 2, '教 1-305', '王老师'),
        _course('马克思主义基本原理', 4, 3, 4, '教 3-201', '李老师'),
        _course('离散数学', 4, 5, 6, '实训楼北 206', '刘老师'),
        _course(
          '离散数学',
          5,
          3,
          4,
          '实训楼北 206',
          '刘老师',
          weeks: [1, 3, 5, 7, 9, 11, 13, 15],
        ),
        _course('形势与政策', 5, 9, 10, '教 2-101', '周老师', weeks: [2, 4, 6, 8]),
        _course('程序设计实践', 5, 9, 10, '实训楼北 101', '吴老师', weeks: [7, 8, 9]),
      ],
    )
    ..plans = [
      PlanItem(
        id: 'a',
        title: 'MIT 16.01 第 4 讲',
        group: 'MIT 16.01',
        date: today,
        startPeriod: 3,
        endPeriod: 4,
      ),
      PlanItem(
        id: 'b',
        title: '18.06 习题 3',
        group: '18.06 线代',
        date: today,
        startPeriod: 7,
        endPeriod: 8,
      ),
      PlanItem(
        id: 'c',
        title: 'MIT 16.01 第 3 讲',
        group: 'MIT 16.01',
        date: today.subtract(const Duration(days: 1)),
        startPeriod: 5,
        endPeriod: 6,
        done: true,
      ),
      const PlanItem(id: 'd', title: '第 5 讲：动量方程', group: 'MIT 16.01'),
      const PlanItem(id: 'e', title: '第 6 讲：能量方程', group: 'MIT 16.01'),
      const PlanItem(
        id: 'f',
        title: 'PSet 2',
        group: 'MIT 16.01',
        deferCount: 1,
      ),
      const PlanItem(id: 'g', title: 'Week 2 Arrays', group: 'CS50'),
    ]
    ..journal = [JournalEntry(date: today, morning: '学完 16.01 第 4 讲')];
  return state;
}

Future<void> _shoot(
  WidgetTester tester,
  String name, {
  required Widget Function(AppState) build,
  bool dark = false,
  String? palette,
  Future<void> Function()? before,
}) async {
  final state = _state(DateTime.now(), dark: dark, palette: palette);
  await tester.pumpWidget(build(state));
  await tester.pump(const Duration(milliseconds: 600));
  if (before != null) await before();
  for (var i = 0; i < 20; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('screenshots/$name.png'),
  );
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await _loadFonts();
  });

  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(1170, 2532)
      ..devicePixelRatio = 3
      ..padding = const FakeViewPadding(top: 141, bottom: 102);
  });

  for (final dark in [false, true]) {
    final suffix = dark ? '_dark' : '';
    testWidgets('today$suffix', (tester) async {
      await _shoot(
        tester,
        'today$suffix',
        dark: dark,
        build: (state) => CourseTableApp(state: state),
      );
    });

    testWidgets('week$suffix', (tester) async {
      await _shoot(
        tester,
        'week$suffix',
        dark: dark,
        build: (state) => CourseTableApp(state: state),
        before: () async {
          await tester.tap(find.text('课表').last);
        },
      );
    });

    testWidgets('plan$suffix', (tester) async {
      await _shoot(
        tester,
        'plan$suffix',
        dark: dark,
        build: (state) => CourseTableApp(state: state),
        before: () async {
          await tester.tap(find.text('自学').last);
        },
      );
    });

    testWidgets('settings$suffix', (tester) async {
      await _shoot(
        tester,
        'settings$suffix',
        dark: dark,
        build: (state) => CourseTableApp(state: state),
        before: () async {
          await tester.tap(find.text('设置').last);
        },
      );
    });
  }

  testWidgets('semester', (tester) async {
    await _shoot(
      tester,
      'semester',
      build: (state) => CourseTableApp(state: state),
      before: () async {
        navigatorKey.currentState!.push(
          SlideRoute((_) => const SemesterPage()),
        );
      },
    );
  });

  testWidgets('schedule', (tester) async {
    await _shoot(
      tester,
      'schedule',
      build: (state) => CourseTableApp(state: state),
      before: () async {
        navigatorKey.currentState!.push(
          SlideRoute((_) => const SchedulePage()),
        );
      },
    );
  });

  testWidgets('morning', (tester) async {
    await _shoot(
      tester,
      'morning',
      build: (state) => CourseTableApp(state: state),
      before: () async {
        navigatorKey.currentState!.push(
          SlideRoute(
            (_) => const ReflectionPage(evening: false),
            ambient: false,
          ),
        );
      },
    );
  });

  testWidgets('evening', (tester) async {
    await _shoot(
      tester,
      'evening',
      build: (state) => CourseTableApp(state: state),
      before: () async {
        navigatorKey.currentState!.push(
          SlideRoute(
            (_) => const ReflectionPage(evening: true),
            ambient: false,
          ),
        );
      },
    );
  });

  // A few other palettes, to check the derived colors hold up.
  for (final (palette, dark) in [
    ('hiana', false),
    ('nord', true),
    ('gruvbox', false),
    ('catppuccin', true),
  ]) {
    testWidgets('palette_$palette', (tester) async {
      await _shoot(
        tester,
        'palette_$palette',
        dark: dark,
        palette: palette,
        build: (state) => CourseTableApp(state: state),
      );
    });
  }

  // Switching palettes at runtime must repaint everything, including const
  // widgets that read Brand directly: this should match palette_hiana.
  testWidgets('palette_switch', (tester) async {
    late AppState app;
    await _shoot(
      tester,
      'palette_switch',
      build: (state) => CourseTableApp(state: app = state),
      before: () async {
        await app.setAppearance(app.appearance.copyWith(paletteId: 'hiana'));
      },
    );
  });

  testWidgets('appearance', (tester) async {
    await _shoot(
      tester,
      'appearance',
      build: (state) => CourseTableApp(state: state),
      before: () async {
        await tester.tap(find.text('设置').last);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.drag(
          find.byType(Scrollable).last,
          const Offset(0, -1700),
        );
      },
    );
  });

  // Text fields with and without content, to catch overlapping labels.
  testWidgets('input_plan', (tester) async {
    await _shoot(
      tester,
      'input_plan',
      build: (state) => CourseTableApp(state: state),
      before: () async {
        await tester.tap(find.text('自学').last);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.byWidgetPredicate((w) => w is RoundIconButton && w.label == '添加卡片').last);
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.enterText(find.byType(EditableText).first, 'MIT 16.01');
      },
    );
  });

  testWidgets('input_event', (tester) async {
    await _shoot(
      tester,
      'input_event',
      build: (state) => CourseTableApp(state: state),
      before: () async {
        await tester.tap(find.byWidgetPredicate((w) => w is RoundIconButton && w.label == '新建事件').last);
        for (var i = 0; i < 10; i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.enterText(find.byType(EditableText).first, '社团例会');
      },
    );
  });

  testWidgets('input_prompt', (tester) async {
    await _shoot(
      tester,
      'input_prompt',
      build: (state) => CourseTableApp(state: state),
      before: () async {
        await tester.tap(find.text('设置').last);
        await tester.pump(const Duration(milliseconds: 400));
        await tester.tap(find.text('晨间问题').first);
        await tester.pump(const Duration(milliseconds: 400));
      },
    );
  });

  // Accessibility guidelines on every tab: 48 dp tap targets and labelled
  // buttons.
  for (final tab in ['今天', '课表', '自学', '设置']) {
    testWidgets('a11y $tab', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(CourseTableApp(state: _state(DateTime.now())));
      await tester.pump(const Duration(milliseconds: 600));
      await tester.tap(find.text(tab).last);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      // textContrastGuideline is not asserted: it samples rendered pixels
      // and misreads thin CJK strokes over the gradient as background.
      handle.dispose();
    });
  }
}

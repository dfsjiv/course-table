# AGENTS.md · 给接手的人和 AI 看的工作说明

CourseTable：本地优先的安卓课表（Flutter + flutter_miuix，Rust 解析易班 `.xls`，小米超级岛走 Kotlin 前台服务）。
功能介绍见 [README.md](README.md)。这份文件记录**工作约定、代码地图、已经修过的坑**。最后更新：2026-11-04。

## 工作约定

- 回复和文案一律用简体中文。文案要有信息量：不写「好好休息」「空课」这类没有内容的占位话，数量为 0 的项不显示。
- 界面不用 Material 控件，统一用 flutter_miuix 和 `lib/ui/common.dart`、`lib/ui/glass.dart` 里的组件。`MaterialApp` 只用来提供本地化和文本编辑。
- 输入框一律用 `AppTextField`（`lib/ui/common.dart`），不要直接用 `MiuixTextField`：它的浮动标签会压在文字上。
- 颜色一律从 `Brand` / `Palette`（`lib/ui/tokens.dart`）取，不要写死品牌色。配色由用户在设置里选，写死的颜色换配色时不会变。
- 改完跑：`flutter analyze`、`flutter test`、`cd rust && cargo test`；改了界面再跑 `flutter test tool/screenshots_test.dart --update-goldens`，看 `tool/screenshots/` 下的图。截图需要思源黑体，路径见测试文件开头。
- 只格式化自己改过的文件，不要对整个 `lib` 跑 `dart format`。
- `android/` 不进仓库，CI 里 `flutter create` 生成后由 `tool/configure_android_*.py` 注入通知和超级岛代码。超级岛的 Kotlin 源码在 `tool/android_island/`，改的是这里。
- 推到 `main` 会自动构建并发布 `latest` Release，所以改动先推别的分支。

## 代码地图

- `lib/app_state.dart`：全部状态，页面只调它的方法。`lib/storage.dart`：SharedPreferences 读写。
- `lib/theme_palette.dart`：配色。12 套内置配色照搬海纳协会网站（`src/client/styles/palettes.css`），每套浅、深各 7 个基色；`parsePalette` 支持海纳 JSON、base16 / base24、VS Code 主题、CSS 变量。
- `lib/ui/tokens.dart`：`Brand` 从当前配色推导所有颜色，文字色会自动加深/提亮到在每种玻璃底上都达到 WCAG AA（`test/contrast_test.dart` 对每套配色都检查）。
- `lib/main.dart`：根部 `Brand.use(...)`；配色、深浅、字体变化时把整棵树标脏重建一次（很多 const 组件直接读 `Brand`，不依赖主题）。
- `lib/user_font.dart`：导入的字体用 `FontLoader` 注册，每次导入换一个新文件名（引擎不能替换已加载的字体族）。
- `lib/ui/appearance_picker.dart`：设置里的配色方块。
- 超级岛：Dart 侧 `lib/island_controller.dart`，Kotlin 侧 `tool/android_island/.../IslandService.kt`（每秒判断状态，内容变了才重发）和 `FocusIsland.kt`（`miui.focus.param` 负载）。`lib/reminders.dart` 的 `islandState` 与 Kotlin 逻辑保持一致。

## 2026-11-04 修过的问题

- **超级岛不出现**：
  - 岛模板的文字块字段写成了 `miui.focus.paramtextInfo`，正确的是 `textInfo`；小岛没有图片（`picInfo` + `miui.focus.pics` 图片包），系统会丢掉整座岛。
  - Android 10–13 上 `startForeground` 传了只有 Android 14 才有的 `specialUse` 类型，会直接抛异常，服务起不来。
  - App 启动时不会重新拉起被系统杀掉的服务，现在打开 App 时会自动恢复。
  - 「下一节」倒计时精确到秒，每秒重发一次焦点通知；改成按分钟。
  - 没有白名单时小米仍然只显示普通通知，这是小米侧限制，代码修不了（见 README）。
- **掉帧**：底部玻璃导航栏每帧把整页按设备像素比（3 倍）`toImageSync` 截一次图，滚动时每帧一张全分辨率截图。改成 1 倍（模糊后看不出区别，像素少 9 倍）。另外背景图按屏幕尺寸解码，`existsSync` 不再每次 build 都调，晨间页呼吸动画单独一层。
- **乱发提醒**：没设开学日期时周次永远算成第 1 周，单双周、后几周才上的课每周都会提醒。现在没有开学日期就不排课前提醒、不显示超级岛，设置里会提示先填开学日期。
- **文案**：自学卡片在「今天」卡片上标题显示成「空课」、课表格子里写「空课」、周末显示「今天的课都结束了 / 好好休息」、统计里出现「0 个自学」，都改掉了。
- **输入框文字重叠**：miuix 的浮动标签画在第一行文字上方 8 px、字号 10，在 MiSans 等行高大的字体和中文输入法下会压住输入内容。现在全部改成占位提示（有字就消失），并给输入文字固定行高。
- **主题**：照海纳协会网站做了自选配色（12 套 + 导入）和自选字体（导入 `.ttf` / `.otf`），默认配色改为网站同款「水色」。

## 还没做的 / 需要真机确认的

- 超级岛负载按公开资料修正，**需要在澎湃 OS 2 / 3 真机上确认**岛的样子；Kotlin 代码只在 CI 里编译（本地没有 Android SDK）。
- 超级岛目前只显示课程，不显示自定义事件和自学卡片。
- 晨间 / 晚间页（`reflection_page.dart`）是固定的暖色调，不跟配色走。

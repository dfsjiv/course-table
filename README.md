# CourseTable

一款简洁、本地优先的安卓课表应用。

CourseTable 可以导入学校易班导出的旧版 `.xls` 课表文件，自动解析课程、周次、单双周、教师和教室，并根据手机日期展示当天课程。

所有课表、设置和自定义事件均保存在设备本地，不需要注册账号，也不需要联网使用。

## 功能

- 导入易班导出的 `.xls` 课表
- 解析周次、单双周和分周更换教室
- 根据手机日期自动显示当前教学周和当天课程
- 按天切换课程，也可切换到整周大课表
- 显示下一节课程或事件的实时倒计时
- 设置课前提醒，App 退出后仍可发送系统通知
- 创建一次性或每周重复的自定义课程和事件
- 编辑和删除自定义事件
- 浅色、深色和跟随系统主题
- 导入本地图片作为背景，并调节背景可见度
- 背景图片保持原始比例并适配不同尺寸的手机屏幕
- 本地保存数据，无账号、无云同步
- GitHub Actions 云端构建安卓、Windows 和未签名 iOS 版本

## 下载安装

前往 [Releases](https://github.com/dfsjiv/course-table/releases/latest)，按平台下载：

- 安卓：`app-arm64-v8a-release.apk`
- Windows：`course-table-windows-x64.zip`，解压后运行 `course_table.exe`
- iOS：`course-table-ios-unsigned.zip`

安卓下载完成后，打开 APK 并允许安装未知来源应用。

iOS 压缩包是未签名构建产物，普通 iPhone 无法直接安装，需要苹果开发者账号和签名证书。

## 使用方法

1. 在易班或学校教学综合信息平台导出班级课表 `.xls` 文件。
2. 打开 CourseTable，点击“导入易班课表”。
3. 选择导出的 `.xls` 文件。
4. 导入后，软件会根据手机日期自动显示当天课程。
5. 点击右上角通知图标，可设置提前提醒时间。
6. 点击“新建事件”，可添加临时事件或每周重复事件。
7. 在设置中可切换主题、选择背景图片和调节背景可见度。

## 导入格式

当前版本主要适配易班教学综合信息服务平台导出的旧版 `.xls` 班级课表。

文件中没有班级名称时，软件仍可正常导入和显示课程，页面标题会显示为“我的课表”。

如果 Excel 格式与当前适配格式差异较大，软件可能无法识别课程。

## 提醒说明

- 首次启用提醒时，请允许通知权限。
- 部分安卓系统可能限制后台通知，需要允许 CourseTable 后台运行。
- 修改提醒时间、重新导入课表或编辑自定义事件后，软件会重新安排未来提醒。

## 技术栈

- Flutter：应用界面和本地功能
- Rust + `calamine`：解析旧版 `.xls` 文件
- `flutter_local_notifications`：本地系统通知
- GitHub Actions：云端测试、构建 APK 和发布 Release

## 云端构建

仓库推送到 `main` 分支后，GitHub Actions 会自动：

1. 生成 Android 工程。
2. 运行 Flutter 测试。
3. 运行 Rust 解析测试。
4. 编译 Rust Android 动态库。
5. 构建 ARM64 APK。
6. 将 APK 发布到 `latest` Release。

也可以在仓库的 **Actions > Build Android APK** 页面手动运行工作流。

## 本地开发

需要安装 Flutter、Rust 和 Android SDK。

```bash
flutter pub get
flutter test

cd rust
cargo test
```

Android 构建还需要使用 `cargo-ndk` 编译 Rust 动态库。项目当前主要通过 GitHub Actions 完成完整构建。

## 隐私

- 不上传课表文件。
- 不保存易班或教务系统账号密码。
- 不收集用户数据。
- 背景图片、课表和自定义事件仅保存在设备本地。

## 当前限制

- 目前主要提供 Android ARM64 安装包。
- iOS 和 Windows 版本尚未发布。
- 当前只适配特定易班 `.xls` 课表结构。
- 不同手机厂商的省电策略可能导致通知略有延迟。

## License

项目当前尚未添加开源许可证。添加许可证前，代码默认保留所有权利。

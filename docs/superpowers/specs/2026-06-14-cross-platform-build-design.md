# Cross-Platform Cloud Build Design

## Goal

Use GitHub Actions to build and publish CourseTable for Windows and iOS without installing local Flutter, Rust, Android, Windows, or Apple development environments.

## Outputs

- Windows: `course-table-windows-x64.zip`, containing `course_table.exe`, Flutter runtime files, plugins, and `course_table_parser.dll`.
- iOS: `course-table-ios-unsigned.zip`, containing the unsigned `Runner.app`.

The Windows ZIP is directly usable after extraction. The unsigned iOS app is a build artifact for testing or later signing; normal iPhones cannot install it without Apple signing.

## Architecture

GitHub Actions generates Flutter platform projects during each build, matching the existing Android workflow. Rust remains the XLS parser:

- Windows compiles Rust as a DLL and copies it beside the executable.
- iOS compiles Rust as a static library and force-loads it through Xcode linker settings so Dart FFI symbols are retained.

Scheduled system notifications remain enabled on Android and iOS. Windows skips scheduling because the notification plugin does not provide equivalent scheduled-notification behavior. In-app countdowns remain available everywhere.

## Publishing

Both workflows upload build artifacts and attach their archives to the existing `latest` GitHub Release. Android, Windows, and iOS assets can therefore be downloaded from one release page.

## Verification

Each workflow runs Flutter tests and Rust tests before building. Successful cloud builds and uploaded release assets are the acceptance criteria.

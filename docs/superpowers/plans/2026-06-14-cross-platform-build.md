# Cross-Platform Cloud Build Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build and publish Windows and unsigned iOS versions of CourseTable entirely through GitHub Actions.

**Architecture:** Keep generated Flutter platform projects out of the repository. Each workflow generates its target platform, compiles the Rust parser in the platform-native form, links or copies it into the Flutter application, builds an archive, and publishes it to the existing `latest` release.

**Tech Stack:** Flutter, Dart FFI, Rust, GitHub Actions, Xcode

---

### Task 1: Guard scheduled notifications by platform

**Files:**
- Create: `lib/platform_capabilities.dart`
- Create: `test/platform_capabilities_test.dart`
- Modify: `lib/notification_service.dart`

- [ ] Add tests proving Android and iOS support scheduled notifications while Windows does not.
- [ ] Add a small platform capability function.
- [ ] Skip notification initialization and scheduling on unsupported platforms.
- [ ] Run Flutter tests in GitHub Actions.

### Task 2: Support an iOS Rust static library

**Files:**
- Modify: `rust/Cargo.toml`
- Create: `tool/configure_ios_rust.py`

- [ ] Add `staticlib` to Rust library crate types.
- [ ] Add a script that copies and force-loads the compiled static library.
- [ ] Link the static library into the generated Flutter iOS project.

### Task 3: Add Windows cloud build and release

**Files:**
- Create: `.github/workflows/build-windows.yml`

- [ ] Generate the Windows Flutter project on `windows-latest`.
- [ ] Run Flutter and Rust tests.
- [ ] Compile and copy the Rust DLL.
- [ ] Build and ZIP the Windows application.
- [ ] Upload the artifact and attach it to the `latest` release.

### Task 4: Add iOS cloud build and release

**Files:**
- Create: `.github/workflows/build-ios.yml`

- [ ] Generate the iOS Flutter project on `macos-latest`.
- [ ] Run Flutter and Rust tests.
- [ ] Compile the Rust static library for iOS.
- [ ] Configure Xcode linker settings and build without code signing.
- [ ] ZIP the unsigned App, upload it, and attach it to the `latest` release.

### Task 5: Document downloads and verify cloud builds

**Files:**
- Modify: `README.md`

- [ ] Document Windows and unsigned iOS downloads.
- [ ] Push changes to GitHub.
- [ ] Verify both GitHub Actions runs succeed.
- [ ] Verify both archives appear on the latest release.

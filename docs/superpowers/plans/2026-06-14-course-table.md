# CourseTable Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a local Android timetable app that imports the school's legacy `.xls` timetable and displays courses by week.

**Architecture:** Flutter renders the import and weekly timetable screens. A small Rust library uses `calamine` to parse legacy `.xls` bytes into JSON, exposed to Dart through a narrow FFI boundary. GitHub Actions generates Flutter platform scaffolding, builds the Rust Android libraries, runs tests, and uploads an APK.

**Tech Stack:** Flutter, Dart FFI, Rust, calamine, GitHub Actions

---

### Task 1: Parsing core

- [ ] Add parser fixture tests for week ranges, odd/even weeks, room changes, and incomplete courses.
- [ ] Implement Rust workbook parsing and JSON output.
- [ ] Run Rust tests in GitHub Actions.

### Task 2: Flutter app

- [ ] Add timetable models and filtering tests.
- [ ] Implement local `.xls` file selection and Rust FFI import.
- [ ] Implement empty state and weekly timetable screen.

### Task 3: Cloud build

- [ ] Add GitHub Actions workflow that generates Android scaffolding.
- [ ] Build Rust Android libraries and Flutter APK.
- [ ] Upload the APK as a workflow artifact.

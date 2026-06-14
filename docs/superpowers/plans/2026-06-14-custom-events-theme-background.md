# Custom Events, Theme, and Background Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add local custom events, theme switching, and configurable background images.

**Architecture:** Keep imported courses unchanged and store custom events separately. Merge both sources into a shared daily display model for sorting, countdowns, and notifications. Store appearance settings and copied background image locally.

**Tech Stack:** Flutter, SharedPreferences, file_picker, path_provider, flutter_local_notifications

---

### Task 1: Custom Events

- [ ] Add custom event model and recurrence tests.
- [ ] Persist events and merge them into daily schedules.
- [ ] Add create, edit, and delete UI.
- [ ] Include custom events in countdowns and notifications.

### Task 2: Appearance Settings

- [ ] Persist theme mode, background path, and opacity.
- [ ] Add settings page and theme switching.
- [ ] Copy selected background into app storage and render it behind content.

### Task 3: Verification

- [ ] Run Flutter and Rust tests in GitHub Actions.
- [ ] Build and publish the latest arm64 APK.

import 'dart:io';

bool supportsScheduledNotifications([String? operatingSystem]) {
  final system = operatingSystem ?? Platform.operatingSystem;
  return system == 'android' || system == 'ios';
}

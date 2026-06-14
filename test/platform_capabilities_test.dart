import 'package:course_table/platform_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('scheduled notifications are supported on mobile platforms', () {
    expect(supportsScheduledNotifications('android'), isTrue);
    expect(supportsScheduledNotifications('ios'), isTrue);
  });

  test('scheduled notifications are disabled on desktop platforms', () {
    expect(supportsScheduledNotifications('windows'), isFalse);
    expect(supportsScheduledNotifications('macos'), isFalse);
    expect(supportsScheduledNotifications('linux'), isFalse);
  });
}

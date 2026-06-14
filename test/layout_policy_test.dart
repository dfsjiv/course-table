import 'package:course_table/layout_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('timetable content never extends behind the app bar', () {
    expect(extendTimetableBehindAppBar(), isFalse);
  });
}

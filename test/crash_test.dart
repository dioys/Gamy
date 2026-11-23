import 'package:flutter_test/flutter_test.dart';
import 'package:gamy/main.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

// Crash reports (Nov 23) carry what went wrong and where, never who it was or what they studied.
void main() {
  final o = SentryFlutterOptions();
  crashReportOptions(o);

  test('no personal details, screenshots, screen layout or speed tracking', () {
    expect(o.sendDefaultPii, isFalse);
    expect(o.attachScreenshot, isFalse);
    expect(o.attachViewHierarchy, isFalse);
    expect(o.tracesSampleRate, 0);
  });

  test('no trail of taps, screens or log lines', () {
    expect(o.beforeBreadcrumb!(Breadcrumb(message: 'typed: my lesson'), Hint()), isNull);
  });

  test('an error report loses the user and the computer name', () async {
    final sent = await o.beforeSend!(
        SentryEvent(user: SentryUser(email: 'student@school.edu'), serverName: 'JUANS-LAPTOP'), Hint());
    expect(sent!.user, isNull);
    expect(sent.serverName, isNull);
  });
}

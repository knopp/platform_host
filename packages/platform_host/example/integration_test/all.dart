// All integration tests in one entry point, so the app is built and launched
// once instead of once per file:
//
//   flutter test integration_test/all.dart -d <device>
//
// Not named `*_test.dart`, so running the whole directory doesn't run every
// test twice. The tests share one app process, so each file must clean up
// after itself (close its windows and automation sessions).
import 'package:test/test.dart';

import 'android_window_automation_test.dart' as android_window_automation;
import 'android_window_test.dart' as android_window;
import 'ui_window_automation_test.dart' as ui_window_automation;
import 'ui_window_test.dart' as ui_window;
import 'win32_window_automation_test.dart' as win32_window_automation;
import 'win32_window_test.dart' as win32_window;
import 'window_automation_test.dart' as window_automation;
import 'window_test.dart' as window;

void main() {
  group('android_window_automation', android_window_automation.main);
  group('android_window', android_window.main);
  group('ui_window_automation', ui_window_automation.main);
  group('ui_window', ui_window.main);
  group('win32_window_automation', win32_window_automation.main);
  group('win32_window', win32_window.main);
  group('window_automation', window_automation.main);
  group('window', window.main);
}

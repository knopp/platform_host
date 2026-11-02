// Touches from real, OS-level input (UI Automator on Android) as seen through
// the platform_host API. Run with the launcher, which starts the agent:
//
//   dart run platform_automation:test -d <adb serial> integration_test
import 'dart:io';

import 'package:platform_automation/uiautomator.dart';
import 'package:platform_host/android.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  platformGroup('Android', Platform.isAndroid, () {
    late UiAutomator automator;
    late UiDevice device;

    /// Pixels per dp; UI Automator works in pixels, touches arrive in dp.
    late double density;

    setUpAll(() async {
      automator = await UiAutomator.connect();
      device = automator.device;
      density =
          await device.getDisplayWidth() / (await device.getDisplaySizeDp()).x;
    });
    tearDownAll(() => automator.close());

    late AndroidWindow window;
    late UiObject2 view;

    setUp(() async {
      window = AndroidWindow()..identifier = 'main';
      final found = await device.wait(
        Until.findObject(By.pkg(automator.packageName).desc('main')),
        const Duration(seconds: 10),
      );
      expect(found, isNotNull);
      view = found!;
    });

    tearDown(() => window.close());

    test('tap is reported at the view center', () async {
      final bounds = await view.getVisibleBounds();
      final gesture = nextGesture(window.touches);

      await view.click();

      final touches = await gesture;
      expect(touches.map((t) => t.phase), [TouchPhase.began, TouchPhase.ended]);
      for (final touch in touches) {
        expect(touch.x, closeTo(bounds.width() / 2 / density, 1));
        expect(touch.y, closeTo(bounds.height() / 2 / density, 1));
      }
    });

    test('drag is reported from start to end', () async {
      final bounds = await view.getVisibleBounds();
      Point at(double x, double y) => Point(
        bounds.left + (x * density).round(),
        bounds.top + (y * density).round(),
      );
      final gesture = nextGesture(window.touches);

      // Holds at the start for 40 steps (~200 ms), then moves in as many.
      final from = at(100, 300);
      await device.swipeSegments([from, from, at(200, 500)], 40);

      final touches = await gesture;
      expect(touches.first.phase, TouchPhase.began);
      expect(touches.first.x, closeTo(100, 1));
      expect(touches.first.y, closeTo(300, 1));
      expect(touches.where((t) => t.phase == TouchPhase.moved), isNotEmpty);
      expect(touches.last.phase, TouchPhase.ended);
      expect(touches.last.x, closeTo(200, 1));
      expect(touches.last.y, closeTo(500, 1));
    });
  });
}

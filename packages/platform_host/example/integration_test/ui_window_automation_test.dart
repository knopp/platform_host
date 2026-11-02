// Touches from real, OS-level input (XCUITest on iOS) as seen through the
// platform_host API. Run with the launcher, which starts the agent:
//
//   dart run platform_automation:test -d <simulator> integration_test
import 'dart:io';

import 'package:platform_automation/xcuitest.dart';
import 'package:platform_host/ios.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  platformGroup('iOS', Platform.isIOS, () {
    late XCUIAutomation automation;

    setUpAll(() async => automation = await XCUIAutomation.connect());
    tearDownAll(() => automation.close());

    late UIWindow window;
    late XCUIElement view;

    setUp(() async {
      window = UIWindow()..identifier = 'main';
      view = automation.application.otherElements['main'];
      expect(
        await view.waitForExistenceWithTimeout(const Duration(seconds: 10)),
        isTrue,
      );
    });

    tearDown(() => window.close());

    test('tap is reported at the view center', () async {
      final frame = await view.frame;
      final gesture = nextGesture(window.touches);

      await view.tap();

      final touches = await gesture;
      expect(touches.map((t) => t.phase), [TouchPhase.began, TouchPhase.ended]);
      for (final touch in touches) {
        expect(touch.x, closeTo(frame.width / 2, 1));
        expect(touch.y, closeTo(frame.height / 2, 1));
      }
    });

    test('drag is reported from start to end', () async {
      final gesture = nextGesture(window.touches);

      final origin = view.coordinateWithNormalizedOffset(const CGVector(0, 0));
      await origin
          .coordinateWithOffset(const CGVector(100, 300))
          .pressForDurationThenDragToCoordinate(
            const Duration(milliseconds: 200),
            origin.coordinateWithOffset(const CGVector(200, 500)),
          );

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

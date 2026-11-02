// Window behavior under real, OS-level input (XCUITest on macOS), checked
// against what the platform_host API reports.
import 'dart:io';

import 'package:platform_automation/xcuitest.dart';
import 'package:platform_host/macos.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  platformGroup('macOS', Platform.isMacOS, () {
    late XCUIAutomation automation;

    setUpAll(() async => automation = await XCUIAutomation.connect());
    tearDownAll(() => automation.close());

    late NSWindow window;
    late XCUIElement element;

    setUp(() async {
      window = NSWindow()
        ..identifier = 'main'
        ..frame = const Rect(200, 200, 640, 480)
        ..makeKeyAndOrderFront();
      element = automation.application.windows['main'];
      expect(
        await element.waitForExistenceWithTimeout(const Duration(seconds: 10)),
        isTrue,
      );
    });

    tearDown(() => window.close());

    test('window is on screen where the API puts it', () async {
      final before = await element.frame;
      expectSize(before, window.frame);

      window.frame = const Rect(300, 250, 500, 400);

      // XCUITest's screen coordinates have y pointing down, AppKit's up; the
      // top edge (AppKit maxY) moved from 680 to 650.
      final after = await element.frame;
      expectSize(after, window.frame);
      expect(after.minX - before.minX, closeTo(100, 1));
      expect(after.minY - before.minY, closeTo(30, 1));
    });

    test('user resize is visible to the API', () async {
      final before = window.frame;
      final screenBefore = await element.frame;

      // Drag the bottom-right corner.
      final origin = element.coordinateWithNormalizedOffset(
        const CGVector(0, 0),
      );
      await origin
          .coordinateWithOffset(CGVector(before.width - 2, before.height - 2))
          .clickForDurationThenDragToCoordinate(
            const Duration(milliseconds: 200),
            origin.coordinateWithOffset(
              CGVector(before.width + 98, before.height + 48),
            ),
          );

      final after = window.frame;
      // The exact distance depends on how the drag is delivered; what matters
      // is that the window grew from its top-left corner and the API agrees
      // with what's on screen.
      expect(after.width, greaterThan(before.width + 50));
      expect(after.height, greaterThan(before.height + 25));
      expect(after.x, closeTo(before.x, 1));
      expect(after.y + after.height, closeTo(before.y + before.height, 1));
      final screenAfter = await element.frame;
      expectSize(screenAfter, after);
      expect(screenAfter.minX, closeTo(screenBefore.minX, 1));
      expect(screenAfter.minY, closeTo(screenBefore.minY, 1));
    });

    test('agent failures surface as exceptions', () async {
      final missing = automation.application.windows['missing'];
      expect(await missing.exists, isFalse);
      await expectLater(missing.click(), throwsA(isA<AutomationException>()));
      // The agent keeps serving after a failed request.
      expect(await element.exists, isTrue);
    });
  });
}

void expectSize(CGRect actual, Rect expected) {
  final reason = '$actual vs $expected';
  expect(actual.width, closeTo(expected.width, 1), reason: reason);
  expect(actual.height, closeTo(expected.height, 1), reason: reason);
}

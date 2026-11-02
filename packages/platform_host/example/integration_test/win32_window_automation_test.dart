// Window behavior under real, OS-level input (UI Automation and SendInput on
// Windows), checked against what the platform_host API reports.
import 'dart:io';

import 'package:platform_automation/uia.dart';
import 'package:platform_host/windows.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  platformGroup('Windows', Platform.isWindows, () {
    late UIAutomation automation;

    setUpAll(() async => automation = await UIAutomation.connect());
    tearDownAll(() => automation.close());

    late Win32Window window;
    late UIAutomationElement element;

    setUp(() async {
      window = Win32Window()
        ..title = 'main'
        ..frame = const Rect(200, 200, 640, 480)
        ..show();
      element = await findWindow(automation, 'main');
    });

    tearDown(() => window.close());

    test('window is on screen where the API puts it', () async {
      expectFrame(await element.currentBoundingRectangle, window.frame);

      window.frame = const Rect(300, 250, 500, 400);
      expectFrame(await element.currentBoundingRectangle, window.frame);
    });

    test('user resize is visible to the API', () async {
      final before = window.frame;

      // Drag the bottom-right corner, which is in the invisible resize border
      // that Windows 10+ puts around the visible frame.
      final x = (before.x + before.width - 3).round();
      final y = (before.y + before.height - 3).round();

      // The mouse is real: make sure the corner is ours, not that of some
      // other window on top, before pressing.
      final hit = await automation.elementFromPoint(x, y);
      expect(
        await hit.currentNativeWindowHandle,
        await element.currentNativeWindowHandle,
        reason: 'another window covers the corner',
      );

      await drag(x, y, x + 100, y + 50);

      final after = window.frame;
      // The exact distance depends on how the drag is delivered; what matters
      // is that the window grew from its top-left corner and the API agrees
      // with what's on screen.
      expect(after.width, greaterThan(before.width + 50));
      expect(after.height, greaterThan(before.height + 25));
      expect(after.x, before.x);
      expect(after.y, before.y);
      expectFrame(await element.currentBoundingRectangle, after);
    });

    test('failures surface as exceptions', () async {
      await element.release();
      await expectLater(
        element.currentName,
        throwsA(isA<AutomationException>()),
      );
      // The isolate keeps serving after a failed request.
      element = await findWindow(automation, 'main');
      expect(await element.currentName, 'main');
    });
  });
}

/// The app's top-level window titled [name], waiting for it to appear.
Future<UIAutomationElement> findWindow(
  UIAutomation automation,
  String name,
) async {
  final desktop = await automation.getRootElement();
  final condition = automation.createAndCondition(
    automation.createPropertyCondition(UIAProperty.name, name),
    automation.createPropertyCondition(UIAProperty.processId, pid),
  );
  final deadline = DateTime.now().add(const Duration(seconds: 10));
  while (true) {
    final window = await desktop.findFirst(TreeScope.children, condition);
    if (window != null) {
      return window;
    }
    if (DateTime.now().isAfter(deadline)) {
      fail('No window named "$name"');
    }
    await Future<void>.delayed(const Duration(milliseconds: 100));
  }
}

/// Presses the left button at ([x0], [y0]), moves to ([x1], [y1]) in steps,
/// and releases, giving the app time to handle each step.
Future<void> drag(int x0, int y0, int x1, int y1) async {
  Future<void> pause() =>
      Future<void>.delayed(const Duration(milliseconds: 20));

  sendInput([MOUSEINPUT.at(x0, y0)]);
  await pause();
  sendInput([MOUSEINPUT.at(x0, y0, dwFlags: MOUSEEVENTF.leftDown)]);
  await pause();
  const steps = 10;
  for (var i = 1; i <= steps; i++) {
    sendInput([
      MOUSEINPUT.at(x0 + (x1 - x0) * i ~/ steps, y0 + (y1 - y0) * i ~/ steps),
    ]);
    await pause();
  }
  sendInput([MOUSEINPUT.at(x1, y1, dwFlags: MOUSEEVENTF.leftUp)]);
  await Future<void>.delayed(const Duration(milliseconds: 200));
}

void expectFrame(RECT actual, Rect expected) {
  final reason = '$actual vs $expected';
  expect(actual.left, expected.x, reason: reason);
  expect(actual.top, expected.y, reason: reason);
  expect(actual.width, expected.width, reason: reason);
  expect(actual.height, expected.height, reason: reason);
}

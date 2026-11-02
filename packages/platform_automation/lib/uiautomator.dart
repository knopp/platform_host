/// UI Automator for Android, mirrored in Dart.
///
/// ```dart
/// late UiAutomator automator;
/// setUpAll(() async => automator = await UiAutomator.connect());
/// tearDownAll(() => automator.close());
///
/// test('tap', () async {
///   final view = await automator.device.wait(
///     Until.findObject(By.pkg(automator.packageName).desc('main')),
///     const Duration(seconds: 10),
///   );
///   await view!.click();
/// });
/// ```
///
/// See `package:platform_automation/platform_automation.dart` for how the
/// agent runs.
library;

export 'src/agent_connection.dart' show AutomationException;
export 'src/uiautomator.dart';

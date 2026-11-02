/// XCUIAutomation (XCUITest) for macOS and iOS, mirrored in Dart.
///
/// ```dart
/// late XCUIAutomation automation;
/// setUpAll(() async => automation = await XCUIAutomation.connect());
/// tearDownAll(() => automation.close());
///
/// test('resize', () async {
///   final window = automation.application.windows['main'];
///   final corner = window.coordinateWithNormalizedOffset(const CGVector(1, 1));
///   await corner.coordinateWithOffset(const CGVector(-2, -2))
///       .clickForDurationThenDragToCoordinate(
///         const Duration(milliseconds: 200),
///         corner.coordinateWithOffset(const CGVector(100, 50)),
///       );
/// });
/// ```
///
/// See `package:platform_automation/platform_automation.dart` for how the
/// agent runs.
library;

export 'src/agent_connection.dart' show AutomationException;
export 'src/xcuitest.dart';

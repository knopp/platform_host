/// Microsoft UI Automation (Windows), mirrored in Dart, plus `SendInput`
/// for real, OS-level input.
///
/// ```dart
/// late UIAutomation automation;
/// setUpAll(() async => automation = await UIAutomation.connect());
/// tearDownAll(() => automation.close());
///
/// test('window is on screen', () async {
///   final desktop = await automation.getRootElement();
///   final window = await desktop.findFirst(
///     TreeScope.children,
///     automation.createPropertyCondition(UIAProperty.name, 'main'),
///   );
///   print(await window!.currentBoundingRectangle);
/// });
/// ```
///
/// Unlike the other platforms, there's no agent process: the calls run on a
/// background isolate of the app itself (see `src/uia.dart`), so plain
/// `flutter test -d windows` works.
library;

export 'src/agent_connection.dart' show AutomationException;
export 'src/uia.dart';

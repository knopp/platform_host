/// Drives the OS's UI automation from Dart integration tests.
///
/// Each platform's automation API is mirrored as closely as possible, as
/// asynchronous Dart:
///
/// - `package:platform_automation/xcuitest.dart`: XCUIAutomation (XCUITest)
///   on macOS and iOS.
/// - `package:platform_automation/uiautomator.dart`: UI Automator on
///   Android.
///
/// The calls are executed by an agent (`agent/darwin`, `agent/android`)
/// that runs out of process, attached to the app the test runs in, and is
/// controlled over a WebSocket hosted by the test. So tests can use the
/// app's own APIs and real, OS-level input together.
///
/// Run the tests with the launcher, which starts the agent on the device and
/// then runs `flutter test`:
///
/// ```sh
/// dart run platform_automation:test -d <device> integration_test
/// ```
///
/// On macOS, plain `flutter test` works too: connecting then runs the agent
/// itself, so the app must not be sandboxed.
library;

export 'src/agent_connection.dart' show AutomationException;

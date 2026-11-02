# platform_host

Thin Dart bindings for host platform windowing APIs: macOS (`NSWindow`), and
proofs of concept for iOS (`UIWindow`), Android (`AndroidWindow`) and Windows
(`Win32Window`).

## Layout

A pub workspace (`pubspec.yaml`); run `flutter pub get` at the root.

- `flutter_zero/` – [flutter_zero](https://github.com/knopp/flutter_zero)
  submodule (tracks `master`). Used as the Flutter SDK for this repo (see
  `.vscode/settings.json`). It runs Dart on the platform (main) thread with a
  headless engine, which AppKit needs. After cloning:

  ```sh
  git submodule update --init
  ```

- `packages/platform_host/` – the bindings:
  - `src/macos/ph_*.{h,m}` – small Objective-C wrappers (`PHWindow`, …) over
    AppKit. Keeping the native surface small keeps the generated Dart small.
  - `hook/build.dart` – builds `src/` into the `platform_host` code asset with
    `native_toolchain_ninja`.
  - `tool/ffigen.dart` – generates `lib/src/macos/macos_bindings.g.dart` from
    the wrapper headers. Re-run after changing a header (from the package
    directory): `dart run tool/ffigen.dart`.
  - `lib/src/macos/*.dart` – the public Dart API on top of the generated
    bindings (exported from `package:platform_host/macos.dart`).
  - `android/` – Java wrappers (`PHWindow`, …) and a `FlutterPlugin` that only
    provides the application context; activities are tracked with lifecycle
    callbacks, not bound to the engine. `tool/jnigen.dart` generates
    `lib/src/android/android_bindings.g.dart` (`dart run tool/jnigen.dart`).
  - `example/` – Flutter app using the package, and its integration tests. Run
    it with the submodule SDK:

    ```sh
    cd packages/platform_host/example
    ../../../flutter_zero/bin/flutter run -d macos
    ```

- `packages/platform_automation/` – drives the OS's UI automation from Dart
  tests, with a Dart mirror of each platform's own API:
  `package:platform_automation/xcuitest.dart` (XCUIAutomation, macOS and
  iOS) and `package:platform_automation/uiautomator.dart` (UI Automator,
  Android). There's deliberately no common abstraction (yet). The calls are
  executed by an agent that connects to the test over a WebSocket: XCUITest
  in `agent/darwin` (Objective-C, macOS and iOS targets), UI Automator in
  `agent/android` (Java). `bin/test.dart` is the launcher that starts the
  agent where the app can't (iOS, Android). Windows is the exception:
  `package:platform_automation/uia.dart` mirrors Microsoft UI Automation
  (plus `SendInput`) and runs it in-process, on a background isolate in the
  COM multithreaded apartment, so there's no agent.
- `tool/eclipse_classpath.dart` – for Java completion in editors, generates
  an (ignored) Eclipse project over all the repo's Java sources, using the
  Android SDK and the libraries in Gradle's cache
  (`dart run tool/eclipse_classpath.dart`).

## Testing

Unit tests for `platform_host` run on the host: `flutter test` in
`packages/platform_host`.

Integration tests live in
`packages/platform_host/example/integration_test/*_test.dart`. They're
written with `package:test` and run inside the real app, so they use the
platform_host API directly; tests that need real, OS-level input use
`package:platform_automation`, in the platform's own automation API:

```dart
late XCUIAutomation automation;
setUpAll(() async => automation = await XCUIAutomation.connect());
tearDownAll(() => automation.close());

test('user resize is visible to the API', () async {
  final origin = automation.application.windows['main']
      .coordinateWithNormalizedOffset(const CGVector(0, 0));
  await origin.coordinateWithOffset(const CGVector(638, 478))
      .clickForDurationThenDragToCoordinate(
        const Duration(milliseconds: 200),
        origin.coordinateWithOffset(const CGVector(738, 528)),
      );
  expect(window.frame.width, greaterThan(640));
});
```

Run them from `packages/platform_host/example` with the launcher, which
starts the agent for the device and then runs `flutter test` (other
arguments are passed through):

```sh
../../../flutter_zero/bin/dart run platform_automation:test -d macos integration_test
../../../flutter_zero/bin/dart run platform_automation:test -d "iPhone 18 Pro" integration_test
../../../flutter_zero/bin/dart run platform_automation:test -d emulator-5554 integration_test
```

Each test file is its own entry point, so `flutter test` builds and
launches the app once per file. `integration_test/all.dart` imports them
all, so passing it instead of the directory builds and launches once (the
tests then share one app process, so each file must clean up after itself):

```sh
../../../flutter_zero/bin/flutter test integration_test/all.dart -d windows
```

It isn't named `*_test.dart`, so running the directory doesn't pick it up;
add new test files to it.

- iOS: only booted simulators for now. The agent is built once per run and
  serves every test file's app launch.
- Android: devices are named by adb serial. The agent is an instrumentation
  test APK (self-instrumenting, like Appium's UiAutomator2 server), built
  with Gradle through its wrapper JAR and started with `am instrument`. It
  needs a JDK (`JAVA_HOME` or Android Studio's) and the Android SDK
  (`ANDROID_HOME` or its default location).
- macOS: plain `flutter test integration_test -d macos` works too, because
  `XCUIAutomation.connect()` builds (incrementally) and starts the agent itself
  when no launcher is involved; that's why the example's debug build isn't
  sandboxed.
- Windows: plain `flutter test integration_test/all.dart -d windows` (or the
  directory); no launcher or agent. It must run in the desktop session (not over SSH, where windows
  never show).
- The agent's output goes to
  `packages/platform_automation/agent/{darwin,android}/build/agent.log`; on
  Android, also see `adb logcat -s PAAgent`.
- Each file's tests are wrapped in a platform group (`support.dart`):
  `@TestOn` is evaluated against the host, not the device.
- UI automation moves the mouse on macOS and Windows; don't use the machine
  while these tests run. The first run may ask to allow automation (macOS).

## Threading

AppKit must be used on the main thread, and the wrappers assume they are
called there. flutter_zero guarantees that. A plain `dart run` does not, so
only the non-AppKit parts are covered by `flutter test`.

Win32 windows belong to the thread that created them, and their messages are
pumped by that thread's message loop, so `Win32Window` also relies on Dart
running on the platform thread. Creating, moving and renaming a window works
without a message loop, so those are unit-tested with `flutter test` too.

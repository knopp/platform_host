// Runs integration tests together with the UI automation agent.
//
//   dart run platform_automation:test -d <device> [flutter test arguments]
//
// For an iOS simulator or an Android device (by its adb serial, e.g.
// `emulator-5554`), builds the agent, starts it on the device and then runs
// `flutter test` with the agent's port, so `XCUIAutomation.connect()` or
// `UiAutomator.connect()` in the app can connect to it. The agent serves one
// session per app launch (each test file) and is stopped when `flutter test`
// exits.
//
// For macOS (`-d macos`) it just runs `flutter test`; the app starts the
// agent itself.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:platform_automation/src/gradle_agent.dart';
import 'package:platform_automation/src/xcode_agent.dart';

Future<void> main(List<String> args) async {
  final device = _deviceArgument(args);
  if (device == null) {
    _fail('Usage: dart run platform_automation:test -d <device> [flutter test arguments]');
  }
  final flutter = _flutterExecutable();

  if (device == 'macos') {
    exit(await _runFlutterTest(flutter, args));
  }

  final packageDir = File.fromUri(
    (await Isolate.resolvePackageUri(
      Uri.parse('package:platform_automation/platform_automation.dart'),
    ))!,
  ).parent.parent.path;

  final _Agent agent;
  if (await _isAndroidDevice(device)) {
    agent = await _startAndroidAgent(packageDir, device);
  } else if (await _bootedSimulator(device) case final simulator?) {
    agent = await _startIOSAgent(packageDir, simulator);
  } else {
    _fail(
      'No device "$device". Supported are macOS, booted iOS simulators and '
      'Android devices by adb serial.',
    );
  }

  final exitCode = await _runFlutterTest(flutter, [
    ...args,
    '--dart-define=PA_AGENT_PORT=${agent.port}',
  ]);

  await agent.stop();
  exit(exitCode);
}

/// A running agent, connecting to the app's server on [port].
typedef _Agent = ({int port, Future<void> Function() stop});

Future<_Agent> _startIOSAgent(
  String packageDir,
  ({String udid, String name}) simulator,
) async {
  final destination = 'platform=iOS Simulator,id=${simulator.udid}';
  final xcode = XcodeAgent(packageDir);

  stdout.writeln('Building the UI automation agent for ${simulator.name}…');
  _check(
    await Process.run(
      'xcodebuild',
      xcode.xcodebuildArgs(
        'build-for-testing',
        scheme: XcodeAgent.iOSScheme,
        destination: destination,
      ),
    ),
    'Building the agent failed.',
  );
  xcode.writeCompileCommands();

  final port = await _freePort();
  final process = await Process.start(
    'xcodebuild',
    xcode.xcodebuildArgs(
      'test-without-building',
      scheme: XcodeAgent.iOSScheme,
      destination: destination,
    ),
    environment: XcodeAgent.environment(port: port, reconnect: true),
  );
  final log = _logTo(process, '${xcode.projectDir}/build/agent.log');
  stdout.writeln('Agent started on port $port (log: ${log.path}).');

  return (
    port: port,
    stop: () async {
      process.kill();
      await process.exitCode;
      await log.done;
    },
  );
}

Future<_Agent> _startAndroidAgent(String packageDir, String serial) async {
  final gradle = GradleAgent(packageDir);
  final adb = GradleAgent.adb();

  stdout.writeln('Building the UI automation agent for $serial…');
  _check(await gradle.build(), 'Building the agent failed.');
  for (final apk in [gradle.appApk, gradle.testApk]) {
    _check(
      await Process.run(adb, ['-s', serial, 'install', '-r', '-t', apk]),
      'Installing $apk failed.',
    );
  }
  // An agent left behind by an earlier, interrupted run.
  await Process.run(adb, ['-s', serial, 'shell', ...GradleAgent.stopArgs]);

  // The app's server and the agent are both on the device, so the port only
  // needs to be free there; one that is free here is a good guess.
  final port = await _freePort();
  final process = await Process.start(adb, [
    '-s',
    serial,
    'shell',
    ...GradleAgent.instrumentArgs(port: port, reconnect: true),
  ]);
  final log = _logTo(process, '${gradle.projectDir}/build/agent.log');
  stdout.writeln('Agent started on port $port (log: ${log.path}).');

  return (
    port: port,
    stop: () async {
      await Process.run(adb, ['-s', serial, 'shell', ...GradleAgent.stopArgs]);
      process.kill();
      await process.exitCode;
      await log.done;
    },
  );
}

/// Writes [process]'s output to [path].
({String path, Future<void> done}) _logTo(Process process, String path) {
  final sink = (File(path)..createSync(recursive: true)).openWrite();
  final done = Future.wait([
    process.stdout.forEach(sink.add),
    process.stderr.forEach(sink.add),
  ]).then((_) => sink.close());
  return (path: path, done: done);
}

void _check(ProcessResult result, String message) {
  if (result.exitCode != 0) {
    stderr
      ..write(result.stdout)
      ..write(result.stderr);
    _fail(message);
  }
}

/// The value of `-d`/`--device-id`.
String? _deviceArgument(List<String> args) {
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if ((arg == '-d' || arg == '--device-id') && i + 1 < args.length) {
      return args[i + 1];
    }
    if (arg.startsWith('--device-id=')) {
      return arg.substring('--device-id='.length);
    }
  }
  return null;
}

/// The `flutter` of the SDK whose `dart` runs this script.
String _flutterExecutable() {
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root != null) {
    return '$root/bin/flutter';
  }
  // <flutter>/bin/cache/dart-sdk/bin/dart
  final sdkBin = File(Platform.resolvedExecutable).parent;
  final flutter = File('${sdkBin.parent.parent.parent.path}/flutter');
  return flutter.existsSync() ? flutter.path : 'flutter';
}

Future<int> _runFlutterTest(String flutter, List<String> args) async {
  final process = await Process.start(flutter, [
    'test',
    ...args,
  ], mode: ProcessStartMode.inheritStdio);
  return process.exitCode;
}

/// Whether [device] is the serial of a device connected to adb.
Future<bool> _isAndroidDevice(String device) async {
  try {
    final result = await Process.run(GradleAgent.adb(), ['devices']);
    return const LineSplitter()
        .convert(result.stdout as String)
        .skip(1)
        .map((line) => line.split('\t'))
        .any((fields) => fields.length == 2 && fields[0] == device);
  } on ProcessException {
    // No adb.
    return false;
  }
}

Future<({String udid, String name})?> _bootedSimulator(String device) async {
  final result = await Process.run('xcrun', [
    'simctl',
    'list',
    'devices',
    'booted',
    '--json',
  ]);
  if (result.exitCode != 0) {
    return null;
  }
  final runtimes =
      (jsonDecode(result.stdout as String) as Map)['devices'] as Map;
  for (final devices in runtimes.values) {
    for (final simulator in devices as List) {
      final {'udid': String udid, 'name': String name} = simulator as Map;
      if (udid == device || name == device) {
        return (udid: udid, name: name);
      }
    }
  }
  return null;
}

Future<int> _freePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(64);
}

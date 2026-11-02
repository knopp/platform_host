import 'dart:convert';
import 'dart:io';

/// How to build and run the XCUITest agent (`agent/darwin`), shared by the
/// in-app start on macOS and the host-side launcher (`bin/test.dart`).
class XcodeAgent {
  XcodeAgent(String packageDirectory)
    : projectDir = '$packageDirectory/agent/darwin';

  final String projectDir;

  static const macOSScheme = 'PAAgent';
  static const iOSScheme = 'PAAgentIOS';

  /// Arguments for `xcodebuild <action>` of [scheme] on [destination].
  List<String> xcodebuildArgs(
    String action, {
    required String scheme,
    required String destination,
  }) => [
    action,
    '-project',
    '$projectDir/PAAgent.xcodeproj',
    '-scheme',
    scheme,
    '-destination',
    destination,
    '-derivedDataPath',
    '$projectDir/build',
    if (action.startsWith('test'))
      '-only-testing:$scheme/PAAgentServer/testServe',
  ];

  /// Environment for running the agent: xcodebuild passes TEST_RUNNER_-
  /// prefixed variables (without the prefix) to the test runner.
  static Map<String, String> environment({
    required int port,
    bool reconnect = false,
  }) => {
    'TEST_RUNNER_PA_AGENT_URL': 'ws://127.0.0.1:$port',
    if (reconnect) 'TEST_RUNNER_PA_AGENT_RECONNECT': '1',
  };

  /// Merges the per-file fragments clang writes during the agent build
  /// (`-gen-cdb-fragment-path build/cdb`, see PAAgent.xcodeproj) into
  /// `compile_commands.json` next to the project, for clangd.
  ///
  /// Each fragment is one JSON object followed by a comma. Fragments of
  /// earlier builds may linger, so only the newest one per source file is
  /// kept.
  void writeCompileCommands() {
    try {
      final fragments =
          Directory('$projectDir/build/cdb')
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.json'))
              .toList()
            ..sort(
              (a, b) => a.lastModifiedSync().compareTo(b.lastModifiedSync()),
            );
      final commands = <String, Object?>{};
      for (final fragment in fragments) {
        final json = fragment.readAsStringSync().trim();
        final command = jsonDecode(
          json.endsWith(',') ? json.substring(0, json.length - 1) : json,
        ) as Map<String, Object?>;
        commands[command['file'] as String] = command;
      }
      File('$projectDir/compile_commands.json').writeAsStringSync(
        const JsonEncoder.withIndent('  ').convert(commands.values.toList()),
      );
    } on Exception {
      // Best effort; it only matters for editor tooling.
    }
  }
}

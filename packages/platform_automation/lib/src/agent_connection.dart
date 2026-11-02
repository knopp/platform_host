import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'agent_location.dart';
import 'xcode_agent.dart';

/// A failed request: the agent's (native) error, e.g. a failed XCUITest
/// assertion or a UI Automator exception.
class AutomationException implements Exception {
  AutomationException(this.message);

  final String message;

  @override
  String toString() => 'AutomationException: $message';
}

/// A session with the UI automation agent, which connects to a WebSocket
/// server hosted here and executes requests:
///
/// ```
/// request:  {"id": 1, "method": "XCUIElement.tap", "params": {...}}
/// response: {"id": 1, "result": <json>} or {"id": 1, "error": "..."}
/// ```
///
/// The methods are the agent's (see `agent/darwin` and `agent/android`);
/// the platform APIs (`xcuitest.dart`, `uiautomator.dart`) are built on top.
class AgentConnection {
  AgentConnection._(this._server, this._socket, this._agent, this._log) {
    _socket.listen(
      (message) {
        final response = jsonDecode(message as String) as Map<String, Object?>;
        final completer = _pending.remove(response['id']);
        if (response['error'] case final String error) {
          completer?.completeError(AutomationException(error));
        } else {
          completer?.complete(response['result']);
        }
      },
      onDone: () {
        for (final completer in _pending.values) {
          completer.completeError(
            AutomationException('Agent disconnected\n${_logTail()}'),
          );
        }
        _pending.clear();
      },
    );
  }

  /// Port of a running agent, set by the launcher (`bin/test.dart`).
  static const _launcherPort = int.fromEnvironment('PA_AGENT_PORT');

  /// Connects to the agent.
  ///
  /// Under the launcher, the agent is already running and connects to the
  /// port it was given. Otherwise, on macOS, this builds (incrementally) and
  /// starts the agent.
  static Future<AgentConnection> connect({
    Duration timeout = const Duration(minutes: 3),
  }) async {
    if (_launcherPort != 0) {
      final server = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        _launcherPort,
      );
      return _connect(server, null, null, timeout);
    }
    if (!Platform.isMacOS) {
      throw AutomationException(
        'No agent. Run the tests with '
        '`dart run platform_automation:test -d <device> …`.',
      );
    }

    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final xcode = XcodeAgent(packageDirectory);
    final agent = await Process.start(
      'xcodebuild',
      xcode.xcodebuildArgs(
        'test',
        scheme: XcodeAgent.macOSScheme,
        destination: 'platform=macOS',
      ),
      environment: XcodeAgent.environment(port: server.port),
    );
    // Kept for error messages, and written to agent.log (like the launcher's
    // agent) for debugging.
    final log = StringBuffer();
    final logFile = File('${xcode.projectDir}/build/agent.log')
      ..createSync(recursive: true);
    final logSink = logFile.openWrite();
    agent.stdout.transform(utf8.decoder).listen((text) {
      log.write(text);
      logSink.write(text);
    });
    agent.stderr.transform(utf8.decoder).listen((text) {
      log.write(text);
      logSink.write(text);
    });
    unawaited(agent.exitCode.then((_) => logSink.close()));

    final connection = await _connect(server, agent, log, timeout);
    // The agent has been built by now; refresh its compile database.
    xcode.writeCompileCommands();
    return connection;
  }

  static Future<AgentConnection> _connect(
    HttpServer server,
    Process? agent,
    StringBuffer? log,
    Duration timeout,
  ) async {
    final WebSocket socket;
    try {
      socket = await Future.any([
        // No compression: it's loopback, and the Android agent's OkHttp
        // rejects the extension parameters dart:io negotiates.
        server
            .transform(
              WebSocketTransformer(
                compression: CompressionOptions.compressionOff,
              ),
            )
            .first,
        if (agent != null)
          agent.exitCode.then<WebSocket>(
            (code) => throw AutomationException(
              'Agent exited with $code before connecting\n'
              '${_tail('$log')}',
            ),
          ),
      ]).timeout(timeout);
    } on TimeoutException {
      agent?.kill();
      await server.close(force: true);
      throw AutomationException(
        'Agent did not connect within $timeout\n${_tail('${log ?? ''}')}',
      );
    }
    return AgentConnection._(server, socket, agent, log);
  }

  final HttpServer _server;
  final WebSocket _socket;

  /// The agent's `xcodebuild`, when [connect] ran it; null under the launcher.
  final Process? _agent;
  final StringBuffer? _log;
  final _pending = <int, Completer<Object?>>{};
  var _nextId = 0;

  /// Sends a request and returns its result.
  Future<Object?> call(
    String method, [
    Map<String, Object?> params = const {},
  ]) {
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _socket.add(jsonEncode({'id': id, 'method': method, 'params': params}));
    return completer.future;
  }

  /// Ends the session. If [connect] ran the agent, also waits for it to exit;
  /// a launcher's agent stays up for the next app launch.
  Future<void> close() async {
    await call('stop');
    await _socket.close();
    final agent = _agent;
    if (agent != null) {
      await agent.exitCode.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          agent.kill();
          return -1;
        },
      );
    }
    await _server.close(force: true);
  }

  String _logTail() => _tail('${_log ?? ''}');
}

String _tail(String log, [int lines = 40]) {
  final all = log.trimRight().split('\n');
  return all.skip(max(0, all.length - lines)).join('\n');
}

import 'dart:io';

/// How to build and run the UI Automator agent (`agent/android`), used by
/// the launcher (`bin/test.dart`).
///
/// The agent is an instrumentation test of an otherwise empty app; the test
/// APK instruments that app and, through UiAutomation, drives any app on the
/// device.
class GradleAgent {
  GradleAgent(String packageDirectory)
    : projectDir = '$packageDirectory/agent/android';

  final String projectDir;

  static const _package = 'dev.platformhost.automation';

  String get appApk => '$projectDir/build/outputs/apk/debug/PAAgent-debug.apk';

  String get testApk =>
      '$projectDir/build/outputs/apk/androidTest/debug/'
      'PAAgent-debug-androidTest.apk';

  /// Builds both APKs, running Gradle through its wrapper JAR (no `gradlew`
  /// script).
  Future<ProcessResult> build() {
    _writeLocalProperties();
    return Process.run(_java(), [
      '-cp',
      '$projectDir/gradle/wrapper/gradle-wrapper.jar',
      'org.gradle.wrapper.GradleWrapperMain',
      '--quiet',
      'assembleDebug',
      'assembleDebugAndroidTest',
    ], workingDirectory: projectDir);
  }

  /// Arguments for `adb shell` that run the agent, connecting to the app's
  /// server on [port].
  static List<String> instrumentArgs({
    required int port,
    bool reconnect = false,
  }) => [
    'am',
    'instrument',
    '-w',
    '-e',
    'PA_AGENT_URL',
    'ws://127.0.0.1:$port',
    if (reconnect) ...['-e', 'PA_AGENT_RECONNECT', '1'],
    '-e',
    'class',
    '$_package.PAAgentServer#testServe',
    '$_package.test/androidx.test.runner.AndroidJUnitRunner',
  ];

  /// Arguments for `adb shell` that stop a running agent; killing the local
  /// `adb` doesn't stop the instrumentation on the device.
  static List<String> get stopArgs => ['am', 'force-stop', _package];

  /// Points the build at the Android SDK.
  void _writeLocalProperties() {
    File('$projectDir/local.properties')
        .writeAsStringSync('sdk.dir=${androidSdkRoot()}\n');
  }

  /// The Android SDK: ANDROID_HOME, ANDROID_SDK_ROOT or its default location.
  static String androidSdkRoot() {
    final environment = Platform.environment;
    return environment['ANDROID_HOME'] ??
        environment['ANDROID_SDK_ROOT'] ??
        (Platform.isMacOS
            ? '${environment['HOME']}/Library/Android/sdk'
            : '${environment['HOME']}/Android/Sdk');
  }

  /// `adb` from the SDK, falling back to the one on PATH.
  static String adb() {
    final adb = File('${androidSdkRoot()}/platform-tools/adb');
    return adb.existsSync() ? adb.path : 'adb';
  }

  /// A JDK for Gradle: JAVA_HOME, Android Studio's bundled one (as the
  /// Flutter tool uses), or `java` on PATH.
  static String _java() {
    final home = Platform.environment['HOME'];
    final candidates = [
      if (Platform.environment['JAVA_HOME'] case final javaHome?)
        '$javaHome/bin/java',
      if (Platform.isMacOS) ...[
        '/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java',
        '$home/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/java',
      ],
    ];
    for (final java in candidates) {
      if (File(java).existsSync()) {
        return java;
      }
    }
    return 'java';
  }
}

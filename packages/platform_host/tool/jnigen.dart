// Regenerates the JNI bindings for the Java wrappers in `android/`.
//
// Run with: dart run tool/jnigen.dart
//
// Needs a JDK and the Android SDK (found through ANDROID_HOME,
// ANDROID_SDK_ROOT or the default location).
import 'dart:io';

import 'package:jnigen/jnigen.dart';

void main() async {
  final packageRoot = Platform.script.resolve('../');
  await JniGenerator(
    input: Input(
      // Only the class Dart uses; the rest of the package is internal (and
      // PHPlugin would need the Flutter embedding on the classpath).
      classes: ['dev.platformhost.PHWindow'],
      sourcePath: [packageRoot.resolve('android/src/main/java/')],
      androidSdk: AndroidSdk(versions: [36], sdkRoot: _androidSdkRoot()),
    ),
    output: Output(
      dart: DartOutput(
        path: packageRoot.resolve('lib/src/android/android_bindings.g.dart'),
        structure: OutputStructure.singleFile,
      ),
    ),
  ).generate();
}

Uri _androidSdkRoot() {
  final environment = Platform.environment;
  final path =
      environment['ANDROID_HOME'] ??
      environment['ANDROID_SDK_ROOT'] ??
      (Platform.isMacOS
          ? '${environment['HOME']}/Library/Android/sdk'
          : '${environment['HOME']}/Android/Sdk');
  return Uri.directory(path);
}

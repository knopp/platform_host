// Regenerates the FFI bindings for the native wrappers in `src/`.
//
// Run with: dart run tool/ffigen.dart
import 'dart:io';

import 'package:ffigen/ffigen.dart';

void main() {
  if (!Platform.isMacOS) {
    throw UnsupportedError('Bindings are generated with the Xcode SDKs.');
  }
  final packageRoot = Platform.script.resolve('../');
  final sourceRoot = packageRoot.resolve('src/');

  _generate(
    header: sourceRoot.resolve('macos/ph_window.h'),
    dartFile: packageRoot.resolve('lib/src/macos/macos_bindings.g.dart'),
    objectiveCFile: sourceRoot.resolve('macos/macos_bindings.g.m'),
  );
  _generate(
    header: sourceRoot.resolve('ios/ph_ui_window.h'),
    dartFile: packageRoot.resolve('lib/src/ios/ios_bindings.g.dart'),
    objectiveCFile: sourceRoot.resolve('ios/ios_bindings.g.m'),
    // Parse against the iOS SDK rather than the host's macOS one. Custom
    // options replace ffigen's defaults, so add clang's builtin headers too.
    compilerOptions: [
      '-isysroot',
      _xcrun(['--sdk', 'iphonesimulator', '--show-sdk-path']),
      '-target',
      'arm64-apple-ios15.0-simulator',
      '-I${_xcrun(['clang', '-print-resource-dir'])}/include',
      '-Wno-nullability-completeness',
    ],
  );
}

void _generate({
  required Uri header,
  required Uri dartFile,
  required Uri objectiveCFile,
  List<String>? compilerOptions,
}) {
  FfiGenerator(
    headers: Headers(entryPoints: [header], compilerOptions: compilerOptions),
    output: Output(
      dartFile: dartFile,
      objectiveCFile: objectiveCFile,
      format: true,
      style: NativeExternalBindings(
        assetId: 'package:platform_host/platform_host',
      ),
    ),
    functions: Functions(
      include: (declaration) => declaration.originalName.startsWith('ph_'),
    ),
    objectiveC: ObjectiveC(
      interfaces: Interfaces(
        include: (declaration) => declaration.originalName.startsWith('PH'),
      ),
      protocols: Protocols(
        include: (declaration) => declaration.originalName.startsWith('PH'),
      ),
    ),
  ).generate();
}

String _xcrun(List<String> args) {
  final result = Process.runSync('xcrun', args);
  if (result.exitCode != 0) {
    throw StateError('xcrun ${args.join(' ')} failed: ${result.stderr}');
  }
  return (result.stdout as String).trim();
}

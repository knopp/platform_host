import 'dart:convert';
import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_ninja/native_toolchain_ninja.dart';

// The agent is an Xcode project inside this package, built and run at test
// time. The running app has no way to look up where a package lives
// (`Isolate.resolvePackageUri` is unsupported there), so bake the package
// location into a tiny native library.
void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets ||
        input.config.code.targetOS != OS.macOS) {
      return;
    }

    final packageDir = Directory.fromUri(input.packageRoot).absolute.path;
    final source = File.fromUri(
      input.outputDirectory.resolve('agent_location.c'),
    );
    // A JSON string literal is also a valid C string literal for any path.
    source.writeAsStringSync(
      'const char *pa_agent_location(void) {\n'
      '  return ${jsonEncode(packageDir)};\n'
      '}\n',
    );

    await NinjaBuilder.library(
      name: 'platform_automation',
      assetName: 'agent_location',
      sources: [source.path],
    ).run(
      input: input,
      output: output,
      logger: Logger('')
        ..level = Level.ALL
        // ignore: avoid_print
        ..onRecord.listen((record) => print(record.message)),
    );
  });
}

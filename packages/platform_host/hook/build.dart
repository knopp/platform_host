import 'dart:io';

import 'package:code_assets/code_assets.dart';
import 'package:hooks/hooks.dart';
import 'package:logging/logging.dart';
import 'package:native_toolchain_ninja/native_toolchain_ninja.dart';

/// Native sources and frameworks per target OS.
const _platforms = {
  OS.macOS: (
    sources: ['src/macos/ph_window.m'],
    generated: 'src/macos/macos_bindings.g.m',
    frameworks: ['Foundation', 'AppKit'],
  ),
  OS.iOS: (
    sources: ['src/ios/ph_ui_window.m'],
    generated: 'src/ios/ios_bindings.g.m',
    frameworks: ['Foundation', 'CoreGraphics', 'UIKit'],
  ),
};

void main(List<String> args) async {
  await build(args, (input, output) async {
    if (!input.config.buildCodeAssets) {
      return;
    }
    final platform = _platforms[input.config.code.targetOS];
    if (platform == null) {
      return;
    }

    final builder = NinjaBuilder.library(
      name: 'platform_host',
      assetName: 'platform_host',
      sources: [
        ...platform.sources,
        // Emitted by tool/ffigen.dart only once the headers need it (blocks,
        // protocols), so it may not exist.
        if (File.fromUri(
          input.packageRoot.resolve(platform.generated),
        ).existsSync())
          platform.generated,
      ],
      includes: ['src'],
      language: Language.objectiveC,
      frameworks: platform.frameworks,
      flags: ['-fobjc-arc'],
      buildMode: BuildMode.debug,
      optimizationLevel: OptimizationLevel.o0,
    );
    await builder.run(
      input: input,
      output: output,
      logger: Logger('')
        ..level = Level.ALL
        // ignore: avoid_print
        ..onRecord.listen((record) => print(record.message)),
    );
  });
}

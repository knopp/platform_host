import 'dart:ffi';

import 'package:ffi/ffi.dart';

@Native<Pointer<Utf8> Function()>(
  symbol: 'pa_agent_location',
  assetId: 'package:platform_automation/agent_location',
)
external Pointer<Utf8> _agentLocation();

/// Absolute path of this package's directory, recorded by the build hook.
String get packageDirectory => _agentLocation().toDartString();

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:platform_host/android.dart';
import 'package:platform_host/ios.dart';
import 'package:platform_host/macos.dart';

// Kept alive for the lifetime of the app; native windows are closed once the
// Dart object is garbage collected.
late final Object window;

void main() {
  if (Platform.isAndroid) {
    final androidWindow = AndroidWindow()..identifier = 'main';
    androidWindow.touches.listen((touch) => print('touch: $touch'));
    window = androidWindow;
    return;
  }

  if (Platform.isIOS) {
    final uiWindow = UIWindow()..identifier = 'main';
    uiWindow.touches.listen((touch) => print('touch: $touch'));
    window = uiWindow;
    return;
  }

  final nsWindow = NSWindow();
  print('initial frame: ${nsWindow.frame}');

  nsWindow.frame = const Rect(100, 100, 640, 480);
  print('frame after set: ${nsWindow.frame}');

  nsWindow.makeKeyAndOrderFront();
  window = nsWindow;
}

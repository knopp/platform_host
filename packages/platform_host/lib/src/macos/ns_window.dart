import 'dart:ffi';

import 'package:objective_c/objective_c.dart' as objc;

import '../geometry.dart';
import 'macos_bindings.g.dart';

/// An AppKit `NSWindow`.
///
/// The underlying window is created hidden and is closed once this object is
/// garbage collected.
final class NSWindow {
  NSWindow() : _window = _create();

  static PHWindow _create() {
    // No-op native call; makes the Dart runtime load the native library (and
    // with it the `PH*` Objective-C classes) before they are looked up.
    ph_macos_init();
    return PHWindow.alloc().init();
  }

  final PHWindow _window;

  /// The window frame in AppKit screen coordinates (origin at the bottom-left
  /// corner of the primary screen).
  Rect get frame {
    final frame = _window.frame;
    return Rect(
      frame.origin.x,
      frame.origin.y,
      frame.size.width,
      frame.size.height,
    );
  }

  set frame(Rect value) {
    final frame = Struct.create<objc.CGRect>();
    frame.origin.x = value.x;
    frame.origin.y = value.y;
    frame.size.width = value.width;
    frame.size.height = value.height;
    _window.frame = frame;
  }

  String get title => _window.title.toDartString();

  set title(String value) => _window.title = value.toNSString();

  /// Accessibility identifier, used by UI automation (e.g. XCUITest) to find
  /// the window independently of its title.
  String? get identifier => _window.identifier?.toDartString();

  set identifier(String? value) => _window.identifier = value?.toNSString();

  /// Shows the window and makes it the key window.
  void makeKeyAndOrderFront() => _window.makeKeyAndOrderFront();

  /// Removes the window from the screen without waiting for this object to
  /// be garbage collected.
  void close() => _window.close();
}

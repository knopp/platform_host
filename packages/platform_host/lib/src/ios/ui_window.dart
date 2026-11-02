import 'dart:async';

import 'package:objective_c/objective_c.dart' as objc;

import '../touch.dart';
import 'ios_bindings.g.dart';

/// A UIKit `UIWindow` showing a single view that reports [touches].
///
/// The window is created in the app's window scene and shown right away (or
/// as soon as UIKit connects the scene). It's hidden by [close], or once this
/// object is garbage collected.
final class UIWindow {
  UIWindow() : _window = _create() {
    _window.touchHandler =
        ObjCBlock_ffiVoid_PHTouchPhase_ffiDouble_ffiDouble.listener(
          (phase, x, y) =>
              _touches.add(TouchEvent(_phases[phase]!, x, y)),
        );
  }

  static PHUIWindow _create() {
    // No-op native call; makes the Dart runtime load the native library (and
    // with it the `PH*` Objective-C classes) before they are looked up.
    ph_ios_init();
    return PHUIWindow.alloc().init();
  }

  static const _phases = {
    PHTouchPhase.PHTouchPhaseBegan: TouchPhase.began,
    PHTouchPhase.PHTouchPhaseMoved: TouchPhase.moved,
    PHTouchPhase.PHTouchPhaseEnded: TouchPhase.ended,
    PHTouchPhase.PHTouchPhaseCancelled: TouchPhase.cancelled,
  };

  final PHUIWindow _window;
  final _touches = StreamController<TouchEvent>.broadcast();

  /// Touches on the window's view, delivered asynchronously.
  Stream<TouchEvent> get touches => _touches.stream;

  /// Accessibility identifier of the window's view, used by UI automation
  /// (e.g. XCUITest) to find it.
  String? get identifier => _window.identifier?.toDartString();

  set identifier(String? value) =>
      _window.identifier = value?.toNSString();

  /// Hides the window and stops delivering [touches].
  void close() {
    _window.touchHandler = null;
    _window.close();
    _touches.close();
  }
}

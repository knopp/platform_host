import 'dart:async';

import 'package:jni/jni.dart';

import '../touch.dart';
import 'android_bindings.g.dart';

/// A single view, shown as the content of an Android activity, that reports
/// [touches].
///
/// The view goes into the oldest live activity, or into the next one created
/// if there is none yet (Dart starts before the launcher activity). Once that
/// activity is destroyed the window stays detached. It's removed by [close],
/// or once this object is garbage collected.
final class AndroidWindow {
  AndroidWindow() : _window = PHWindow() {
    _finalizer.attach(this, _window, detach: this);
    _window.touchListener = PHWindow$TouchListener.implement(
      $PHWindow$TouchListener(
        onTouch: (phase, x, y) =>
            _touches.add(TouchEvent(_phases[phase]!, x, y)),
        // Delivered as a message rather than a blocking call into Dart.
        onTouch$async: true,
      ),
    );
  }

  static final _finalizer = Finalizer<PHWindow>((window) => window.close());

  static const _phases = {
    PHWindow.PHASE_BEGAN: TouchPhase.began,
    PHWindow.PHASE_MOVED: TouchPhase.moved,
    PHWindow.PHASE_ENDED: TouchPhase.ended,
    PHWindow.PHASE_CANCELLED: TouchPhase.cancelled,
  };

  final PHWindow _window;
  final _touches = StreamController<TouchEvent>.broadcast();

  /// Touches on the window's view, delivered asynchronously.
  Stream<TouchEvent> get touches => _touches.stream;

  /// Content description of the window's view, used by UI automation (e.g.
  /// UI Automator) to find it.
  String? get identifier =>
      _window.identifier?.toDartString(releaseOriginal: true);

  set identifier(String? value) => _window.identifier = value?.toJString();

  /// Removes the view and stops delivering [touches].
  void close() {
    _finalizer.detach(this);
    _window.close();
    _touches.close();
  }
}

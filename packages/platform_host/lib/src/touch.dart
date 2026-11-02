enum TouchPhase { began, moved, ended, cancelled }

/// A touch reported by a view.
final class TouchEvent {
  const TouchEvent(this.phase, this.x, this.y);

  final TouchPhase phase;

  /// Location in points (dp on Android), relative to the view's top-left
  /// corner.
  final double x;
  final double y;

  @override
  String toString() => 'TouchEvent(${phase.name}, $x, $y)';
}

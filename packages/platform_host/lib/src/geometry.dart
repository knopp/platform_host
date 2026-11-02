/// An axis-aligned rectangle in logical (point) coordinates.
final class Rect {
  const Rect(this.x, this.y, this.width, this.height);

  final double x;
  final double y;
  final double width;
  final double height;

  @override
  bool operator ==(Object other) =>
      other is Rect &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() => 'Rect($x, $y, $width, $height)';
}

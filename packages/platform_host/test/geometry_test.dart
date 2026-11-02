import 'package:platform_host/platform_host.dart';
import 'package:test/test.dart';

void main() {
  test('Rect equality', () {
    expect(const Rect(1, 2, 3, 4), const Rect(1, 2, 3, 4));
    expect(const Rect(1, 2, 3, 4), isNot(const Rect(1, 2, 3, 5)));
  });
}

@TestOn('windows')
library;

import 'package:platform_host/windows.dart';
import 'package:test/test.dart';

// Win32 calls don't need a message loop to create, move or rename a window,
// so (unlike macOS) this runs under plain `flutter test`.
void main() {
  late Win32Window window;

  setUp(() => window = Win32Window());
  tearDown(() => window.close());

  test('frame round-trips', () {
    const frame = Rect(100, 100, 640, 480);
    window.frame = frame;
    expect(window.frame, frame);
  });

  test('title round-trips', () {
    window.title = 'Héllo ✓';
    expect(window.title, 'Héllo ✓');
  });

  test('close is idempotent', () {
    window.close();
    window.close();
  });
}

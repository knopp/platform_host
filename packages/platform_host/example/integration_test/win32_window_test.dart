import 'dart:io';

import 'package:platform_host/windows.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  platformGroup('Windows', Platform.isWindows, () {
    late Win32Window window;

    setUp(() => window = Win32Window());
    tearDown(() => window.close());

    test('new window has a default frame', () {
      expect(window.frame.width, greaterThan(0));
      expect(window.frame.height, greaterThan(0));
    });

    test('frame round-trips', () {
      const frame = Rect(100, 100, 640, 480);
      window.frame = frame;
      expect(window.frame, frame);
    });

    test('show keeps the frame', () {
      const frame = Rect(120, 140, 400, 300);
      window.frame = frame;
      window.show();
      expect(window.frame, frame);
    });

    test('title round-trips', () {
      expect(window.title, isEmpty);
      window.title = 'Hello';
      expect(window.title, 'Hello');
    });
  });
}

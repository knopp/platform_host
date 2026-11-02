import 'dart:io';

import 'package:platform_host/macos.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  platformGroup('macOS', Platform.isMacOS, () {
    late NSWindow window;

    setUp(() => window = NSWindow());
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

    test('makeKeyAndOrderFront keeps the frame', () {
      const frame = Rect(120, 140, 400, 300);
      window.frame = frame;
      window.makeKeyAndOrderFront();
      expect(window.frame, frame);
    });

    test('title and identifier round-trip', () {
      expect(window.identifier, isNull);

      window.title = 'Hello';
      window.identifier = 'main';
      expect(window.title, 'Hello');
      expect(window.identifier, 'main');

      window.identifier = null;
      expect(window.identifier, isNull);
    });
  });
}

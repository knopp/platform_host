import 'dart:io';

import 'package:platform_host/ios.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  platformGroup('iOS', Platform.isIOS, () {
    late UIWindow window;

    setUp(() => window = UIWindow());
    tearDown(() => window.close());

    test('identifier round-trips', () {
      expect(window.identifier, isNull);

      window.identifier = 'main';
      expect(window.identifier, 'main');

      window.identifier = null;
      expect(window.identifier, isNull);
    });

    test('close stops touches', () async {
      window.close();
      expect(await window.touches.isEmpty, isTrue);
    });
  });
}

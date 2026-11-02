@TestOn('mac-os')
library;

import 'package:objective_c/objective_c.dart' as objc;
import 'package:platform_host/src/macos/macos_bindings.g.dart';
import 'package:test/test.dart';

// Creating an NSWindow needs the main run loop, which `dart test` does not
// run, so this only checks that the native library builds and loads.
void main() {
  test('native library registers PHWindow', () {
    ph_macos_init();
    // `alloc` only, `init` would create the NSWindow.
    expect(PHWindow.isA(PHWindow.alloc()), isTrue);
    expect(PHWindow.isA(objc.NSObject()), isFalse);
  });
}

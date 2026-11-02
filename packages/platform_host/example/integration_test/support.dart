import 'dart:async';

import 'package:platform_host/ios.dart' show TouchEvent, TouchPhase;
import 'package:test/test.dart';

/// Declares a group that only runs on one platform.
///
/// `@TestOn` doesn't work for these tests: for integration tests on a device,
/// `flutter test` evaluates it against the host, not the device.
void platformGroup(String platform, bool isCurrent, void Function() body) =>
    group(platform, body, skip: isCurrent ? false : '$platform only');

/// [touches] until (and including) the first `ended` one.
Future<List<TouchEvent>> nextGesture(Stream<TouchEvent> touches) => touches
    .transform(_untilEnded)
    .toList()
    .timeout(const Duration(seconds: 10));

/// Passes touches through, closing after the first `ended` one.
final _untilEnded = StreamTransformer<TouchEvent, TouchEvent>.fromHandlers(
  handleData: (touch, sink) {
    sink.add(touch);
    if (touch.phase == TouchPhase.ended) {
      sink.close();
    }
  },
);

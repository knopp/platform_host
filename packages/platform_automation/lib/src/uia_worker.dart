import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart' show using;

import 'package:win32/win32.dart';

// The isolate that executes UI Automation calls for `uia.dart`.
//
// Requests are `(id, method, args)` records; element methods take the
// element's handle as the first argument. Responses are `(id, result, error)`.
//
// COM: the isolate joins the multithreaded apartment through
// CoIncrementMTAUsage rather than CoInitializeEx, because Dart doesn't pin an
// isolate to an OS thread: between messages it may run on any thread of the
// VM's pool, and pool threads come and go. With the MTA kept alive for the
// process, every thread that hasn't initialized COM is implicitly in it, and
// the (free-threaded) UIA objects can be used from whichever thread runs the
// isolate. That thread never owns windows, as UIA requires of clients that
// automate their own process.

/// Entry point; [responses] first receives the [SendPort] for requests, or
/// an error message if UI Automation can't be created.
void uiaWorkerMain(SendPort responses) {
  final CO_MTA_USAGE_COOKIE cookie;
  final IUIAutomation automation;
  try {
    cookie = CoIncrementMTAUsage();
    automation = createInstance<IUIAutomation>(CUIAutomation);
  } catch (e) {
    responses.send('Failed to create CUIAutomation: $e');
    return;
  }

  final requests = ReceivePort('UIAutomation requests');
  final worker = _Worker(automation);
  responses.send(requests.sendPort);
  requests.listen((message) {
    final (id, method, args) = message as (int, String, List<Object?>);
    try {
      final result = worker.call(method, args);
      responses.send((id, result, null));
    } catch (e) {
      responses.send((id, null, '$method: $e'));
    }
    if (method == 'close') {
      requests.close();
      automation.release();
      CoDecrementMTAUsage(cookie);
    }
  });
}

final class _Worker {
  _Worker(this._automation);

  final IUIAutomation _automation;
  final _elements = <int, IUIAutomationElement>{};
  var _nextHandle = 1;

  Object? call(String method, List<Object?> args) => switch (method) {
    'getRootElement' => _add(_automation.getRootElement()),
    'elementFromPoint' => using((arena) {
      final point = arena<POINT>().ref
        ..x = args[0]! as int
        ..y = args[1]! as int;
      return _add(_automation.elementFromPoint(point));
    }),
    'elementFromHandle' => _add(
      _automation.elementFromHandle(HWND(Pointer.fromAddress(args[0]! as int))),
    ),
    'findFirst' => _findFirst(
      _element(args[0]),
      TreeScope(args[1]! as int),
      args[2]!,
    ),
    'currentName' => _string(_element(args[0]).currentName),
    'currentClassName' => _string(_element(args[0]).currentClassName),
    'currentProcessId' => _element(args[0]).currentProcessId,
    'currentNativeWindowHandle' => _element(
      args[0],
    ).currentNativeWindowHandle.address,
    'currentBoundingRectangle' => _rect(
      _element(args[0]).currentBoundingRectangle,
    ),
    'release' => _release(args[0]! as int),
    'close' => _closeAll(),
    _ => throw ArgumentError('Unknown method $method'),
  };

  int? _add(IUIAutomationElement? element) {
    if (element == null) {
      return null;
    }
    final handle = _nextHandle++;
    _elements[handle] = element;
    return handle;
  }

  IUIAutomationElement _element(Object? handle) =>
      _elements[handle] ?? (throw StateError('Element $handle was released'));

  int? _findFirst(
    IUIAutomationElement element,
    TreeScope scope,
    Object description,
  ) {
    final condition = _condition(description);
    try {
      return _add(element.findFirst(scope, condition));
    } finally {
      condition.release();
    }
  }

  IUIAutomationCondition _condition(Object description) =>
      switch (description) {
        ('property', final int id, final Object value) => _property(
          UIA_PROPERTY_ID(id),
          value,
        ),
        ('and', final Object first, final Object second) => () {
          final a = _condition(first);
          final b = _condition(second);
          try {
            return _automation.createAndCondition(a, b)!;
          } finally {
            a.release();
            b.release();
          }
        }(),
        ('true',) => _automation.createTrueCondition()!,
        _ => throw ArgumentError('Bad condition $description'),
      };

  IUIAutomationCondition _property(UIA_PROPERTY_ID id, Object value) {
    final Variant variant = switch (value) {
      final String s => Variant.bstr(s),
      final int i => Variant.int32(i),
      final bool b => Variant.bool$(b),
      _ => throw ArgumentError.value(value),
    };
    try {
      return _automation.createPropertyCondition(id, variant.ref)!;
    } finally {
      variant.free();
    }
  }

  String _string(BSTR value) {
    try {
      return value.toDartString();
    } finally {
      SysFreeString(value);
    }
  }

  (int, int, int, int) _rect(Pointer<RECT> rect) {
    try {
      final r = rect.ref;
      return (r.left, r.top, r.right, r.bottom);
    } finally {
      free(rect);
    }
  }

  Null _release(int handle) {
    _elements.remove(handle)?.release();
    return null;
  }

  Null _closeAll() {
    for (final element in _elements.values) {
      element.release();
    }
    _elements.clear();
    return null;
  }
}

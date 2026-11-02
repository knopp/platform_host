import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;

import 'agent_connection.dart' show AutomationException;
import 'uia_worker.dart';

// Mirrors Microsoft UI Automation's client API (IUIAutomation and
// IUIAutomationElement) and SendInput. Names follow the COM API in
// lowerCamelCase (`FindFirst` -> `findFirst`, `get_CurrentName` ->
// `currentName`).
//
// The UIA calls run on a background isolate, in the COM multithreaded
// apartment: UIA must not be used from the thread that owns the windows being
// automated (here, the platform thread all other Dart code runs on), since it
// talks to them by sending messages to that thread. So every call that
// reaches UIA is asynchronous, and the platform thread keeps pumping messages
// while it waits.
//
// Conditions are plain descriptions, created in the isolate for each call.
// Elements are references to IUIAutomationElements held by the isolate,
// released once the Dart object is garbage collected (or on [release]).

/// A UI Automation client; the entry point, like a `CUIAutomation` instance.
final class UIAutomation {
  UIAutomation._(this._isolate, this._requests, this._responses);

  /// Starts the background isolate that executes the UI Automation calls.
  static Future<UIAutomation> connect() async {
    final responses = ReceivePort('UIAutomation responses');
    final ready = Completer<SendPort>();
    UIAutomation? automation;
    responses.listen((message) {
      switch (message) {
        case SendPort requests when !ready.isCompleted:
          ready.complete(requests);
        case String error when !ready.isCompleted:
          ready.completeError(AutomationException(error));
        case (int id, Object? result, String? error):
          final completer = automation?._pending.remove(id);
          if (error != null) {
            completer?.completeError(AutomationException(error));
          } else {
            completer?.complete(result);
          }
        case _exited:
          // The isolate died (e.g. a crash in native code); fail what's
          // still waiting rather than hanging.
          const error = 'The UI Automation isolate exited';
          if (!ready.isCompleted) {
            ready.completeError(AutomationException(error));
          }
          for (final completer
              in automation?._pending.values ?? <Completer<Object?>>[]) {
            completer.completeError(AutomationException(error));
          }
          automation?._pending.clear();
          automation?._closed = true;
          responses.close();
      }
    });
    final isolate = await Isolate.spawn(
      uiaWorkerMain,
      responses.sendPort,
      debugName: 'UIAutomation',
      onExit: responses.sendPort,
      onError: responses.sendPort,
    );
    return automation = UIAutomation._(isolate, await ready.future, responses);
  }

  /// Sent by the isolate's `onExit` listener (and `onError`, which sends a
  /// list; with errors fatal, an error is followed by the exit).
  static const _exited = null;

  final Isolate _isolate;
  final SendPort _requests;
  final ReceivePort _responses;
  final _pending = <int, Completer<Object?>>{};
  var _nextId = 0;
  var _closed = false;

  late final _elementFinalizer = Finalizer<int>((handle) {
    if (!_closed) {
      _requests.send((_nextId++, 'release', [handle]));
    }
  });

  /// `IUIAutomation::GetRootElement`: the desktop.
  Future<UIAutomationElement> getRootElement() async =>
      _element((await _call('getRootElement', const []))! as int);

  /// `IUIAutomation::ElementFromHandle`.
  Future<UIAutomationElement> elementFromHandle(int hwnd) async =>
      _element((await _call('elementFromHandle', [hwnd]))! as int);

  /// `IUIAutomation::ElementFromPoint`, at physical screen pixel ([x], [y]).
  Future<UIAutomationElement> elementFromPoint(int x, int y) async =>
      _element((await _call('elementFromPoint', [x, y]))! as int);

  /// `IUIAutomation::CreatePropertyCondition`. [value] is a [String], [int]
  /// (sent as `VT_I4`) or [bool], matching the property's type.
  UIAutomationCondition createPropertyCondition(
    UIAProperty property,
    Object value,
  ) => _PropertyCondition(property, value);

  /// `IUIAutomation::CreateAndCondition`.
  UIAutomationCondition createAndCondition(
    UIAutomationCondition condition1,
    UIAutomationCondition condition2,
  ) => _AndCondition(condition1, condition2);

  /// `IUIAutomation::CreateTrueCondition`.
  UIAutomationCondition createTrueCondition() => const _TrueCondition();

  /// Ends the session: releases all elements and stops the isolate.
  Future<void> close() async {
    if (_closed) {
      return;
    }
    await _call('close', const []);
    _closed = true;
    _responses.close();
    _isolate.kill();
  }

  UIAutomationElement _element(int handle) {
    final element = UIAutomationElement._(this, handle);
    _elementFinalizer.attach(element, handle, detach: element);
    return element;
  }

  Future<Object?> _call(String method, List<Object?> args) {
    if (_closed) {
      return Future.error(AutomationException('UIAutomation is closed'));
    }
    final id = _nextId++;
    final completer = Completer<Object?>();
    _pending[id] = completer;
    _requests.send((id, method, args));
    return completer.future;
  }
}

/// `IUIAutomationElement`.
final class UIAutomationElement {
  UIAutomationElement._(this._automation, this._handle);

  final UIAutomation _automation;
  final int _handle;

  /// `IUIAutomationElement::FindFirst`; null if nothing matches.
  Future<UIAutomationElement?> findFirst(
    TreeScope scope,
    UIAutomationCondition condition,
  ) async {
    final handle = await _call('findFirst', [scope.value, condition._encode()]);
    return handle == null ? null : _automation._element(handle as int);
  }

  /// `get_CurrentName`.
  Future<String> get currentName async =>
      (await _call('currentName', const []))! as String;

  /// `get_CurrentClassName`.
  Future<String> get currentClassName async =>
      (await _call('currentClassName', const []))! as String;

  /// `get_CurrentProcessId`.
  Future<int> get currentProcessId async =>
      (await _call('currentProcessId', const []))! as int;

  /// `get_CurrentNativeWindowHandle`; 0 if the element isn't a window.
  Future<int> get currentNativeWindowHandle async =>
      (await _call('currentNativeWindowHandle', const []))! as int;

  /// `get_CurrentBoundingRectangle`, in physical screen pixels (the app is
  /// per-monitor DPI aware).
  Future<RECT> get currentBoundingRectangle async {
    final (left, top, right, bottom) =
        (await _call('currentBoundingRectangle', const []))!
            as (int, int, int, int);
    return RECT(left, top, right, bottom);
  }

  /// `IUnknown::Release`, without waiting for garbage collection.
  Future<void> release() async {
    _automation._elementFinalizer.detach(this);
    await _call('release', const []);
  }

  Future<Object?> _call(String method, List<Object?> args) =>
      _automation._call(method, [_handle, ...args]);
}

/// `IUIAutomationCondition`.
sealed class UIAutomationCondition {
  const UIAutomationCondition();

  Object _encode();
}

final class _PropertyCondition extends UIAutomationCondition {
  _PropertyCondition(this.property, this.value) {
    if (value is! String && value is! int && value is! bool) {
      throw ArgumentError.value(value, 'value', 'Must be String, int or bool');
    }
  }

  final UIAProperty property;
  final Object value;

  @override
  Object _encode() => ('property', property.id, value);
}

final class _AndCondition extends UIAutomationCondition {
  const _AndCondition(this.condition1, this.condition2);

  final UIAutomationCondition condition1;
  final UIAutomationCondition condition2;

  @override
  Object _encode() => ('and', condition1._encode(), condition2._encode());
}

final class _TrueCondition extends UIAutomationCondition {
  const _TrueCondition();

  @override
  Object _encode() => ('true',);
}

/// `TreeScope`; [value] is the native value.
enum TreeScope {
  element(1),
  children(2),
  descendants(4),
  subtree(7),
  parent(8),
  ancestors(16);

  const TreeScope(this.value);

  final int value;
}

/// `UIA_PROPERTY_ID`s (`UIA_<name>PropertyId`); [id] is the native value.
enum UIAProperty {
  processId(30002),
  controlType(30003),
  name(30005),
  automationId(30011),
  className(30012),
  nativeWindowHandle(30020);

  const UIAProperty(this.id);

  final int id;
}

/// `RECT`.
final class RECT {
  const RECT(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;

  int get width => right - left;
  int get height => bottom - top;

  @override
  bool operator ==(Object other) =>
      other is RECT &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'RECT($left, $top, $right, $bottom)';
}

/// `MOUSEINPUT`, for [sendInput].
final class MOUSEINPUT {
  const MOUSEINPUT({
    this.dx = 0,
    this.dy = 0,
    this.mouseData = 0,
    required this.dwFlags,
    this.time = 0,
  });

  /// An absolute move to physical screen pixel ([x], [y]), plus [dwFlags]
  /// (e.g. [MOUSEEVENTF.leftDown]).
  ///
  /// Converts to the normalized (0–65535) virtual desktop coordinates that
  /// `MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_VIRTUALDESK` take.
  factory MOUSEINPUT.at(int x, int y, {int dwFlags = 0}) {
    final left = win32.GetSystemMetrics(win32.SM_XVIRTUALSCREEN);
    final top = win32.GetSystemMetrics(win32.SM_YVIRTUALSCREEN);
    final width = win32.GetSystemMetrics(win32.SM_CXVIRTUALSCREEN);
    final height = win32.GetSystemMetrics(win32.SM_CYVIRTUALSCREEN);
    // Pixel centers, so that rounding inside Windows lands on (x, y).
    int normalize(int value, int origin, int size) =>
        (((value - origin) * 65536 + 32768) / size).floor().clamp(0, 65535);
    return MOUSEINPUT(
      dx: normalize(x, left, width),
      dy: normalize(y, top, height),
      dwFlags:
          dwFlags |
          MOUSEEVENTF.move |
          MOUSEEVENTF.absolute |
          MOUSEEVENTF.virtualDesk,
    );
  }

  final int dx;
  final int dy;
  final int mouseData;
  final int dwFlags;
  final int time;
}

/// `MOUSEEVENTF_*` flags for [MOUSEINPUT.dwFlags].
abstract final class MOUSEEVENTF {
  static const move = 0x0001;
  static const leftDown = 0x0002;
  static const leftUp = 0x0004;
  static const rightDown = 0x0008;
  static const rightUp = 0x0010;
  static const absolute = 0x8000;
  static const virtualDesk = 0x4000;
}

/// `SendInput` with mouse input; returns the number of events inserted.
///
/// Synchronous, like the native call: it only queues the input. It's
/// delivered once the platform thread gets back to its message loop (e.g.
/// while the test awaits), so give the app time between steps of a gesture.
int sendInput(List<MOUSEINPUT> inputs) => using((arena) {
  final native = arena<win32.INPUT>(inputs.length);
  for (final (i, input) in inputs.indexed) {
    native[i].type = win32.INPUT_MOUSE;
    final mi = native[i].Anonymous.mi
      ..dx = input.dx
      ..dy = input.dy
      ..mouseData = input.mouseData
      ..time = input.time;
    mi.dwFlags = win32.MOUSE_EVENT_FLAGS(input.dwFlags);
  }
  final result = win32.SendInput(inputs.length, native, sizeOf<win32.INPUT>());
  if (result.value != inputs.length) {
    throw AutomationException(
      'SendInput inserted ${result.value} of ${inputs.length} events '
      '(error ${result.error})',
    );
  }
  return result.value;
});

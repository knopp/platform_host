import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:win32/win32.dart' as win32;
import 'package:win32/win32.dart' show HWND, PCWSTR, PWSTR, RECT, WNDCLASS;

import '../geometry.dart';

/// A top-level Win32 window (`HWND`).
///
/// The underlying window is created hidden and is destroyed once this object
/// is garbage collected.
///
/// Win32 windows belong to the thread that created them; like the other
/// platforms, this assumes all Dart code runs on the platform (main) thread,
/// which flutter_zero guarantees.
final class Win32Window {
  Win32Window() : _hwnd = _create() {
    _finalizer.attach(this, _hwnd, detach: this);
  }

  static HWND _create() {
    final result = using(
      (arena) => win32.CreateWindowEx(
        win32.WINDOW_EX_STYLE(0),
        _windowClass,
        arena.pcwstr(''),
        win32.WS_OVERLAPPEDWINDOW,
        win32.CW_USEDEFAULT,
        win32.CW_USEDEFAULT,
        win32.CW_USEDEFAULT,
        win32.CW_USEDEFAULT,
        null,
        null,
        _hInstance,
        null,
      ),
    );
    if (result.value.address == 0) {
      throw win32.WindowsException(result.error.toHRESULT());
    }
    return result.value;
  }

  static final _finalizer = Finalizer<HWND>(win32.DestroyWindow);

  static final _hInstance = win32.HINSTANCE(
    win32.GetModuleHandle(null).value,
  );

  /// The window class shared by all [Win32Window]s, registered on first use.
  ///
  /// Messages go straight to `DefWindowProcW`, so there's no Dart callback
  /// that would have to outlive the isolate. A side effect is that closing
  /// the window from its title bar destroys it.
  static final PCWSTR _windowClass = () {
    // Lives as long as the process (the class is never unregistered).
    final name = 'PlatformHostWindow'.toPcwstr(allocator: malloc);
    using((arena) {
      final windowClass = arena<WNDCLASS>()
        ..ref.lpfnWndProc = DynamicLibrary.open(
          'user32.dll',
        ).lookup('DefWindowProcW')
        ..ref.hInstance = _hInstance
        ..ref.hCursor = win32.LoadCursor(null, win32.IDC_ARROW).value
        ..ref.hbrBackground = win32.HBRUSH(
          Pointer.fromAddress(win32.COLOR_WINDOW + 1),
        )
        ..ref.lpszClassName = PWSTR(name);
      final result = win32.RegisterClass(windowClass);
      if (result.value == 0 &&
          result.error != win32.ERROR_CLASS_ALREADY_EXISTS) {
        throw win32.WindowsException(result.error.toHRESULT());
      }
    });
    return name;
  }();

  final HWND _hwnd;
  bool _closed = false;

  /// The window frame (including the non-client area) in physical pixels, in
  /// virtual screen coordinates (origin at the top-left corner of the primary
  /// monitor).
  ///
  /// The frame includes the invisible resize borders that Windows 10+ draws
  /// around the visible window.
  Rect get frame => using((arena) {
    final rect = arena<RECT>();
    _check(win32.GetWindowRect(_hwnd, rect));
    final r = rect.ref;
    return Rect(
      r.left.toDouble(),
      r.top.toDouble(),
      (r.right - r.left).toDouble(),
      (r.bottom - r.top).toDouble(),
    );
  });

  set frame(Rect value) => _check(
    win32.SetWindowPos(
      _hwnd,
      null,
      value.x.round(),
      value.y.round(),
      value.width.round(),
      value.height.round(),
      win32.SWP_NOZORDER | win32.SWP_NOACTIVATE,
    ),
  );

  /// The title bar text. Also the window's name in UI Automation.
  String get title => using((arena) {
    final length = win32.GetWindowTextLength(_hwnd).value;
    final buffer = arena<Uint16>(length + 1).cast<Utf16>();
    final copied = win32.GetWindowText(_hwnd, PWSTR(buffer), length + 1);
    return PCWSTR(buffer).toDartString(length: copied.value);
  });

  set title(String value) => using(
    (arena) =>
        _check(win32.SetWindowText(_hwnd, arena.pcwstr(value))),
  );

  /// Shows the window and brings it to the foreground.
  void show() {
    win32.ShowWindow(_hwnd, win32.SW_SHOW);
    win32.SetForegroundWindow(_hwnd);
  }

  /// Destroys the window without waiting for this object to be garbage
  /// collected. The window can't be used afterwards.
  void close() {
    if (_closed) {
      return;
    }
    _closed = true;
    _finalizer.detach(this);
    win32.DestroyWindow(_hwnd);
  }

  /// Throws if [result] reports failure. (`GetLastError` is only meaningful
  /// after a failed call.)
  static void _check(win32.Win32Result<bool> result) {
    if (!result.value) {
      throw win32.WindowsException(result.error.toHRESULT());
    }
  }
}

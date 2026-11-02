import 'dart:convert';
import 'dart:io';

import 'agent_connection.dart';

// Mirrors UI Automator (androidx.test.uiautomator). Names follow the Java
// API; overloads get distinct names or optional parameters, and durations
// are Durations. Every call that reaches the UI is asynchronous, since the
// agent executes it.
//
// As in UI Automator, selectors and search conditions are values (built
// here, synchronously), while a UiObject2 is a handle to an object the agent
// found: it represents that view and becomes stale if the view goes away.
// Coordinates are pixels.

/// A session with the UI Automator agent (Android); the entry point.
class UiAutomator {
  UiAutomator._(this._connection);

  /// Connects to the agent; see the library documentation.
  static Future<UiAutomator> connect() async =>
      UiAutomator._(await AgentConnection.connect());

  final AgentConnection _connection;

  /// `UiDevice.getInstance(instrumentation)`.
  late final UiDevice device = UiDevice._(this);

  /// The package of the app the test runs in, e.g. for [By.pkg].
  late final String packageName = () {
    // The process name, which for the app's main process is its package.
    final cmdline = File('/proc/self/cmdline').readAsBytesSync();
    final end = cmdline.indexOf(0);
    return utf8.decode(end < 0 ? cmdline : cmdline.sublist(0, end));
  }();

  /// Ends the session.
  Future<void> close() => _connection.close();

  Future<Object?> _call(
    String method, [
    Map<String, Object?> params = const {},
  ]) => _connection.call(method, params);
}

/// `android.graphics.Point`.
final class Point {
  const Point(this.x, this.y);

  final int x;
  final int y;

  @override
  bool operator ==(Object other) =>
      other is Point && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'Point($x, $y)';

  List<int> _toJson() => [x, y];

  static Point _fromJson(Object? json) {
    json as List;
    return Point(json[0] as int, json[1] as int);
  }
}

/// `android.graphics.Rect`.
final class Rect {
  const Rect(this.left, this.top, this.right, this.bottom);

  final int left;
  final int top;
  final int right;
  final int bottom;

  int width() => right - left;
  int height() => bottom - top;
  int centerX() => (left + right) >> 1;
  int centerY() => (top + bottom) >> 1;

  @override
  bool operator ==(Object other) =>
      other is Rect &&
      other.left == left &&
      other.top == top &&
      other.right == right &&
      other.bottom == bottom;

  @override
  int get hashCode => Object.hash(left, top, right, bottom);

  @override
  String toString() => 'Rect($left, $top - $right, $bottom)';

  static Rect _fromJson(Object? json) {
    json as List;
    return Rect(json[0] as int, json[1] as int, json[2] as int, json[3] as int);
  }
}

/// `androidx.test.uiautomator.Direction`.
enum Direction { left, right, up, down }

/// `BySelector`: criteria for matching views. Immutable here; each method
/// returns a selector with the criterion added.
final class BySelector {
  const BySelector._(this._criteria);

  /// `[method, args…]` per criterion; the agent applies them in order,
  /// starting with `By.<method>`.
  final List<List<Object?>> _criteria;

  BySelector _with(List<Object?> criterion) =>
      BySelector._([..._criteria, criterion]);

  BySelector checkable(bool isCheckable) => _with(['checkable', isCheckable]);
  BySelector checked(bool isChecked) => _with(['checked', isChecked]);

  /// A class name, e.g. `android.widget.Button`.
  BySelector clazz(String className) => _with(['clazz', className]);
  BySelector clickable(bool isClickable) => _with(['clickable', isClickable]);
  BySelector depth(int exactDepth) => _with(['depth', exactDepth]);
  BySelector desc(String contentDescription) =>
      _with(['desc', contentDescription]);
  BySelector descContains(String substring) =>
      _with(['descContains', substring]);
  BySelector descEndsWith(String substring) =>
      _with(['descEndsWith', substring]);
  BySelector descStartsWith(String substring) =>
      _with(['descStartsWith', substring]);
  BySelector displayId(int displayId) => _with(['displayId', displayId]);
  BySelector enabled(bool isEnabled) => _with(['enabled', isEnabled]);
  BySelector focusable(bool isFocusable) => _with(['focusable', isFocusable]);
  BySelector focused(bool isFocused) => _with(['focused', isFocused]);
  BySelector hasChild(BySelector childSelector) =>
      _with(['hasChild', childSelector._criteria]);
  BySelector hasDescendant(BySelector descendantSelector, [int? maxDepth]) =>
      _with(['hasDescendant', descendantSelector._criteria, ?maxDepth]);
  BySelector longClickable(bool isLongClickable) =>
      _with(['longClickable', isLongClickable]);
  BySelector maxDepth(int max) => _with(['maxDepth', max]);
  BySelector minDepth(int min) => _with(['minDepth', min]);
  BySelector pkg(String applicationPackage) =>
      _with(['pkg', applicationPackage]);

  /// A resource name, e.g. `com.example:id/button`; or, with [resourceId],
  /// a resource package and ID (`res(String, String)`).
  BySelector res(String resourceName, [String? resourceId]) =>
      _with(['res', resourceName, ?resourceId]);
  BySelector scrollable(bool isScrollable) =>
      _with(['scrollable', isScrollable]);
  BySelector selected(bool isSelected) => _with(['selected', isSelected]);
  BySelector text(String textValue) => _with(['text', textValue]);
  BySelector textContains(String substring) =>
      _with(['textContains', substring]);
  BySelector textEndsWith(String substring) =>
      _with(['textEndsWith', substring]);
  BySelector textStartsWith(String substring) =>
      _with(['textStartsWith', substring]);

  @override
  String toString() => 'BySelector($_criteria)';
}

/// `By`: starts a [BySelector] with one criterion.
abstract final class By {
  static const _empty = BySelector._([]);

  static BySelector checkable(bool isCheckable) =>
      _empty.checkable(isCheckable);
  static BySelector checked(bool isChecked) => _empty.checked(isChecked);
  static BySelector clazz(String className) => _empty.clazz(className);
  static BySelector clickable(bool isClickable) =>
      _empty.clickable(isClickable);
  static BySelector depth(int exactDepth) => _empty.depth(exactDepth);
  static BySelector desc(String contentDescription) =>
      _empty.desc(contentDescription);
  static BySelector descContains(String substring) =>
      _empty.descContains(substring);
  static BySelector descEndsWith(String substring) =>
      _empty.descEndsWith(substring);
  static BySelector descStartsWith(String substring) =>
      _empty.descStartsWith(substring);
  static BySelector displayId(int displayId) => _empty.displayId(displayId);
  static BySelector enabled(bool isEnabled) => _empty.enabled(isEnabled);
  static BySelector focusable(bool isFocusable) =>
      _empty.focusable(isFocusable);
  static BySelector focused(bool isFocused) => _empty.focused(isFocused);
  static BySelector hasChild(BySelector childSelector) =>
      _empty.hasChild(childSelector);
  static BySelector hasDescendant(
    BySelector descendantSelector, [
    int? maxDepth,
  ]) => _empty.hasDescendant(descendantSelector, maxDepth);
  static BySelector longClickable(bool isLongClickable) =>
      _empty.longClickable(isLongClickable);
  static BySelector maxDepth(int max) => _empty.maxDepth(max);
  static BySelector minDepth(int min) => _empty.minDepth(min);
  static BySelector pkg(String applicationPackage) =>
      _empty.pkg(applicationPackage);
  static BySelector res(String resourceName, [String? resourceId]) =>
      _empty.res(resourceName, resourceId);
  static BySelector scrollable(bool isScrollable) =>
      _empty.scrollable(isScrollable);
  static BySelector selected(bool isSelected) => _empty.selected(isSelected);
  static BySelector text(String textValue) => _empty.text(textValue);
  static BySelector textContains(String substring) =>
      _empty.textContains(substring);
  static BySelector textEndsWith(String substring) =>
      _empty.textEndsWith(substring);
  static BySelector textStartsWith(String substring) =>
      _empty.textStartsWith(substring);
}

/// `SearchCondition<R>`: something [UiDevice.wait] waits for.
final class SearchCondition<R> {
  const SearchCondition._(this._name, this._selector, this._decode);

  final String _name;
  final BySelector _selector;
  final R Function(UiAutomator automator, Object? json) _decode;
}

/// `Until`: search conditions.
abstract final class Until {
  static SearchCondition<bool> hasObject(BySelector selector) =>
      SearchCondition._('hasObject', selector, (_, json) => json as bool);

  static SearchCondition<bool> gone(BySelector selector) =>
      SearchCondition._('gone', selector, (_, json) => json as bool);

  static SearchCondition<UiObject2?> findObject(BySelector selector) =>
      SearchCondition._('findObject', selector, UiObject2._fromJson);

  static SearchCondition<List<UiObject2>> findObjects(BySelector selector) =>
      SearchCondition._('findObjects', selector, UiObject2._listFromJson);
}

/// `UiDevice`: the device's state and device-wide input.
final class UiDevice {
  UiDevice._(this._automator);

  final UiAutomator _automator;

  Future<int> getDisplayWidth() async =>
      (await _call('getDisplayWidth')) as int;

  Future<int> getDisplayHeight() async =>
      (await _call('getDisplayHeight')) as int;

  /// The display size in dp; with [getDisplayWidth], gives the density.
  Future<Point> getDisplaySizeDp() async =>
      Point._fromJson(await _call('getDisplaySizeDp'));

  Future<int> getDisplayRotation() async =>
      (await _call('getDisplayRotation')) as int;

  Future<String?> getCurrentPackageName() async =>
      (await _call('getCurrentPackageName')) as String?;

  Future<String> getProductName() async =>
      (await _call('getProductName')) as String;

  Future<bool> hasObject(BySelector selector) async =>
      (await _call('hasObject', {'selector': selector._criteria})) as bool;

  Future<UiObject2?> findObject(BySelector selector) async =>
      UiObject2._fromJson(
        _automator,
        await _call('findObject', {'selector': selector._criteria}),
      );

  Future<List<UiObject2>> findObjects(BySelector selector) async =>
      UiObject2._listFromJson(
        _automator,
        await _call('findObjects', {'selector': selector._criteria}),
      );

  /// Waits up to [timeout] for [condition]; returns its last result.
  Future<R> wait<R>(SearchCondition<R> condition, Duration timeout) async =>
      condition._decode(
        _automator,
        await _call('wait', {
          'condition': condition._name,
          'selector': condition._selector._criteria,
          'timeout': timeout.inMilliseconds,
        }),
      );

  Future<void> waitForIdle([Duration? timeout]) => _call('waitForIdle', {
    if (timeout != null) 'timeout': timeout.inMilliseconds,
  });

  Future<bool> click(int x, int y) async =>
      (await _call('click', {'x': x, 'y': y})) as bool;

  /// Swipes in [steps] steps of about 5 ms each.
  Future<bool> swipe(
    int startX,
    int startY,
    int endX,
    int endY,
    int steps,
  ) async => (await _call('swipe', {
    'startX': startX,
    'startY': startY,
    'endX': endX,
    'endY': endY,
    'steps': steps,
  })) as bool;

  /// `swipe(Point[] segments, int segmentSteps)`: a swipe through
  /// [segments], each taking [segmentSteps] steps of about 5 ms. Repeating
  /// the first point holds the press there.
  Future<bool> swipeSegments(List<Point> segments, int segmentSteps) async =>
      (await _call('swipeSegments', {
        'segments': [for (final point in segments) point._toJson()],
        'segmentSteps': segmentSteps,
      })) as bool;

  Future<bool> drag(
    int startX,
    int startY,
    int endX,
    int endY,
    int steps,
  ) async => (await _call('drag', {
    'startX': startX,
    'startY': startY,
    'endX': endX,
    'endY': endY,
    'steps': steps,
  })) as bool;

  Future<bool> pressBack() async => (await _call('pressBack')) as bool;

  Future<bool> pressHome() async => (await _call('pressHome')) as bool;

  Future<bool> pressEnter() async => (await _call('pressEnter')) as bool;

  Future<bool> pressKeyCode(int keyCode) async =>
      (await _call('pressKeyCode', {'keyCode': keyCode})) as bool;

  Future<Object?> _call(
    String method, [
    Map<String, Object?> params = const {},
  ]) => _automator._call('UiDevice.$method', params);
}

/// `UiObject2`: a view the agent found. Fails with a `StaleObjectException`
/// once the view is gone.
final class UiObject2 {
  UiObject2._(this._automator, this._handle);

  final UiAutomator _automator;
  final int _handle;

  static UiObject2? _fromJson(UiAutomator automator, Object? json) =>
      json == null ? null : UiObject2._(automator, json as int);

  static List<UiObject2> _listFromJson(UiAutomator automator, Object? json) => [
    for (final handle in (json as List).cast<int>())
      UiObject2._(automator, handle),
  ];

  // Properties.

  Future<Rect> getVisibleBounds() async =>
      Rect._fromJson(await _call('getVisibleBounds'));

  Future<Point> getVisibleCenter() async =>
      Point._fromJson(await _call('getVisibleCenter'));

  Future<String?> getApplicationPackage() async =>
      (await _call('getApplicationPackage')) as String?;

  Future<String?> getClassName() async =>
      (await _call('getClassName')) as String?;

  Future<String?> getContentDescription() async =>
      (await _call('getContentDescription')) as String?;

  Future<String?> getResourceName() async =>
      (await _call('getResourceName')) as String?;

  Future<String?> getText() async => (await _call('getText')) as String?;

  Future<int> getDisplayId() async => (await _call('getDisplayId')) as int;

  Future<bool> isCheckable() async => (await _call('isCheckable')) as bool;
  Future<bool> isChecked() async => (await _call('isChecked')) as bool;
  Future<bool> isClickable() async => (await _call('isClickable')) as bool;
  Future<bool> isEnabled() async => (await _call('isEnabled')) as bool;
  Future<bool> isFocusable() async => (await _call('isFocusable')) as bool;
  Future<bool> isFocused() async => (await _call('isFocused')) as bool;
  Future<bool> isLongClickable() async =>
      (await _call('isLongClickable')) as bool;
  Future<bool> isScrollable() async => (await _call('isScrollable')) as bool;
  Future<bool> isSelected() async => (await _call('isSelected')) as bool;

  // Hierarchy.

  Future<UiObject2?> getParent() async =>
      UiObject2._fromJson(_automator, await _call('getParent'));

  Future<int> getChildCount() async => (await _call('getChildCount')) as int;

  Future<List<UiObject2>> getChildren() async =>
      UiObject2._listFromJson(_automator, await _call('getChildren'));

  Future<bool> hasObject(BySelector selector) async =>
      (await _call('hasObject', {'selector': selector._criteria})) as bool;

  Future<UiObject2?> findObject(BySelector selector) async =>
      UiObject2._fromJson(
        _automator,
        await _call('findObject', {'selector': selector._criteria}),
      );

  Future<List<UiObject2>> findObjects(BySelector selector) async =>
      UiObject2._listFromJson(
        _automator,
        await _call('findObjects', {'selector': selector._criteria}),
      );

  // Input.

  /// Clicks the center; holds it for [duration] if given.
  Future<void> click([Duration? duration]) => _call('click', {
    if (duration != null) 'duration': duration.inMilliseconds,
  });

  Future<void> longClick() => _call('longClick');

  /// Drags the center to [dest], at [speed] pixels per second if given.
  Future<void> drag(Point dest, [int? speed]) =>
      _call('drag', {'dest': dest._toJson(), 'speed': ?speed});

  /// Swipes in [direction] over [percent] (0 to 1) of the object.
  Future<void> swipe(Direction direction, double percent, [int? speed]) =>
      _call('swipe', {
        'direction': direction.index,
        'percent': percent,
        'speed': ?speed,
      });

  Future<bool> scroll(
    Direction direction,
    double percent, [
    int? speed,
  ]) async => (await _call('scroll', {
    'direction': direction.index,
    'percent': percent,
    'speed': ?speed,
  })) as bool;

  Future<bool> fling(Direction direction, [int? speed]) async =>
      (await _call('fling', {'direction': direction.index, 'speed': ?speed}))
          as bool;

  Future<void> setText(String text) => _call('setText', {'text': text});

  Future<void> clear() => _call('clear');

  /// Releases the agent's reference to the object.
  Future<void> recycle() => _call('recycle');

  Future<Object?> _call(
    String method, [
    Map<String, Object?> params = const {},
  ]) => _automator._call('UiObject2.$method', {...params, 'object': _handle});
}

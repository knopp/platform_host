import 'package:objective_c/objective_c.dart';

import 'agent_connection.dart';

// Mirrors XCUIAutomation (XCUITest). Names follow the Objective-C API, with
// NSTimeInterval as Duration; every call that reaches the UI is
// asynchronous, since the agent executes it.
//
// Queries, elements and coordinates are lazy, as in XCUITest: they're
// descriptions (paths from an application) that the agent resolves anew on
// each call, so building them is synchronous and doesn't talk to the agent.

/// A session with the XCUITest agent (macOS and iOS); the entry point.
class XCUIAutomation {
  XCUIAutomation._(this._connection);

  /// Connects to the agent; see the library documentation.
  static Future<XCUIAutomation> connect() async =>
      XCUIAutomation._(await AgentConnection.connect());

  final AgentConnection _connection;

  /// The app the test runs in, like `[[XCUIApplication alloc] init]` in a UI
  /// test.
  late final XCUIApplication application = applicationWithBundleIdentifier(
    NSBundle.getMainBundle().bundleIdentifier!.toDartString(),
  );

  /// `-[XCUIApplication initWithBundleIdentifier:]`; attaches to an app, as
  /// its proxy, without launching it.
  XCUIApplication applicationWithBundleIdentifier(String bundleIdentifier) =>
      XCUIApplication._(this, [
        ['application', bundleIdentifier],
      ]);

  /// Ends the session.
  Future<void> close() => _connection.close();

  Future<Object?> _call(String method, Map<String, Object?> params) =>
      _connection.call(method, params);
}

/// `XCUIElementType`; [index] is the native value.
enum XCUIElementType {
  any,
  other,
  application,
  group,
  window,
  sheet,
  drawer,
  alert,
  dialog,
  button,
  radioButton,
  radioGroup,
  checkBox,
  disclosureTriangle,
  popUpButton,
  comboBox,
  menuButton,
  toolbarButton,
  popover,
  keyboard,
  key,
  navigationBar,
  tabBar,
  tabGroup,
  toolbar,
  statusBar,
  table,
  tableRow,
  tableColumn,
  outline,
  outlineRow,
  browser,
  collectionView,
  slider,
  pageIndicator,
  progressIndicator,
  activityIndicator,
  segmentedControl,
  picker,
  pickerWheel,

  /// `XCUIElementTypeSwitch` (`switch` is a Dart keyword).
  switch_,
  toggle,
  link,
  image,
  icon,
  searchField,
  scrollView,
  scrollBar,
  staticText,
  textField,
  secureTextField,
  datePicker,
  textView,
  menu,
  menuItem,
  menuBar,
  menuBarItem,
  map,
  webView,
  incrementArrow,
  decrementArrow,
  timeline,
  ratingIndicator,
  valueIndicator,
  splitGroup,
  splitter,
  relevanceIndicator,
  colorWell,
  helpTag,
  matte,
  dockItem,
  ruler,
  rulerMarker,
  grid,
  levelIndicator,
  cell,
  layoutArea,
  layoutItem,
  handle,
  stepper,
  tab,
  touchBar,
  statusItem,
}

/// `XCUIApplicationState`; [index] is the native value.
enum XCUIApplicationState {
  unknown,
  notRunning,

  /// iOS only.
  runningBackgroundSuspended,
  runningBackground,
  runningForeground,
}

/// `CGPoint`.
final class CGPoint {
  const CGPoint(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) =>
      other is CGPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() => 'CGPoint($x, $y)';
}

/// `CGVector`.
final class CGVector {
  const CGVector(this.dx, this.dy);

  final double dx;
  final double dy;

  @override
  bool operator ==(Object other) =>
      other is CGVector && other.dx == dx && other.dy == dy;

  @override
  int get hashCode => Object.hash(dx, dy);

  @override
  String toString() => 'CGVector($dx, $dy)';

  List<double> _toJson() => [dx, dy];
}

/// `CGRect`, with the `CGRectGet…` functions as getters.
final class CGRect {
  const CGRect(this.x, this.y, this.width, this.height);

  final double x;
  final double y;
  final double width;
  final double height;

  double get minX => x;
  double get minY => y;
  double get midX => x + width / 2;
  double get midY => y + height / 2;
  double get maxX => x + width;
  double get maxY => y + height;

  @override
  bool operator ==(Object other) =>
      other is CGRect &&
      other.x == x &&
      other.y == y &&
      other.width == width &&
      other.height == height;

  @override
  int get hashCode => Object.hash(x, y, width, height);

  @override
  String toString() => 'CGRect($x, $y, $width, $height)';
}

/// `NSPredicate`, as its format string (without arguments).
final class NSPredicate {
  const NSPredicate(this.predicateFormat);

  final String predicateFormat;

  @override
  String toString() => predicateFormat;
}

/// `XCUIElementTypeQueryProvider`: queries for descendants of each type.
mixin XCUIElementTypeQueryProvider {
  XCUIElementQuery descendantsMatchingType(XCUIElementType type);

  /// The first matching element; evaluation stops at the first match.
  XCUIElement get firstMatch;

  XCUIElementQuery get touchBars =>
      descendantsMatchingType(XCUIElementType.touchBar);
  XCUIElementQuery get groups => descendantsMatchingType(XCUIElementType.group);
  XCUIElementQuery get windows =>
      descendantsMatchingType(XCUIElementType.window);
  XCUIElementQuery get sheets => descendantsMatchingType(XCUIElementType.sheet);
  XCUIElementQuery get drawers =>
      descendantsMatchingType(XCUIElementType.drawer);
  XCUIElementQuery get alerts => descendantsMatchingType(XCUIElementType.alert);
  XCUIElementQuery get dialogs =>
      descendantsMatchingType(XCUIElementType.dialog);
  XCUIElementQuery get buttons =>
      descendantsMatchingType(XCUIElementType.button);
  XCUIElementQuery get radioButtons =>
      descendantsMatchingType(XCUIElementType.radioButton);
  XCUIElementQuery get radioGroups =>
      descendantsMatchingType(XCUIElementType.radioGroup);
  XCUIElementQuery get checkBoxes =>
      descendantsMatchingType(XCUIElementType.checkBox);
  XCUIElementQuery get disclosureTriangles =>
      descendantsMatchingType(XCUIElementType.disclosureTriangle);
  XCUIElementQuery get popUpButtons =>
      descendantsMatchingType(XCUIElementType.popUpButton);
  XCUIElementQuery get comboBoxes =>
      descendantsMatchingType(XCUIElementType.comboBox);
  XCUIElementQuery get menuButtons =>
      descendantsMatchingType(XCUIElementType.menuButton);
  XCUIElementQuery get toolbarButtons =>
      descendantsMatchingType(XCUIElementType.toolbarButton);
  XCUIElementQuery get popovers =>
      descendantsMatchingType(XCUIElementType.popover);
  XCUIElementQuery get keyboards =>
      descendantsMatchingType(XCUIElementType.keyboard);
  XCUIElementQuery get keys => descendantsMatchingType(XCUIElementType.key);
  XCUIElementQuery get navigationBars =>
      descendantsMatchingType(XCUIElementType.navigationBar);
  XCUIElementQuery get tabBars =>
      descendantsMatchingType(XCUIElementType.tabBar);
  XCUIElementQuery get tabGroups =>
      descendantsMatchingType(XCUIElementType.tabGroup);
  XCUIElementQuery get toolbars =>
      descendantsMatchingType(XCUIElementType.toolbar);
  XCUIElementQuery get statusBars =>
      descendantsMatchingType(XCUIElementType.statusBar);
  XCUIElementQuery get tables => descendantsMatchingType(XCUIElementType.table);
  XCUIElementQuery get tableRows =>
      descendantsMatchingType(XCUIElementType.tableRow);
  XCUIElementQuery get tableColumns =>
      descendantsMatchingType(XCUIElementType.tableColumn);
  XCUIElementQuery get outlines =>
      descendantsMatchingType(XCUIElementType.outline);
  XCUIElementQuery get outlineRows =>
      descendantsMatchingType(XCUIElementType.outlineRow);
  XCUIElementQuery get browsers =>
      descendantsMatchingType(XCUIElementType.browser);
  XCUIElementQuery get collectionViews =>
      descendantsMatchingType(XCUIElementType.collectionView);
  XCUIElementQuery get sliders =>
      descendantsMatchingType(XCUIElementType.slider);
  XCUIElementQuery get pageIndicators =>
      descendantsMatchingType(XCUIElementType.pageIndicator);
  XCUIElementQuery get progressIndicators =>
      descendantsMatchingType(XCUIElementType.progressIndicator);
  XCUIElementQuery get activityIndicators =>
      descendantsMatchingType(XCUIElementType.activityIndicator);
  XCUIElementQuery get segmentedControls =>
      descendantsMatchingType(XCUIElementType.segmentedControl);
  XCUIElementQuery get pickers =>
      descendantsMatchingType(XCUIElementType.picker);
  XCUIElementQuery get pickerWheels =>
      descendantsMatchingType(XCUIElementType.pickerWheel);
  XCUIElementQuery get switches =>
      descendantsMatchingType(XCUIElementType.switch_);
  XCUIElementQuery get toggles =>
      descendantsMatchingType(XCUIElementType.toggle);
  XCUIElementQuery get links => descendantsMatchingType(XCUIElementType.link);
  XCUIElementQuery get images => descendantsMatchingType(XCUIElementType.image);
  XCUIElementQuery get icons => descendantsMatchingType(XCUIElementType.icon);
  XCUIElementQuery get searchFields =>
      descendantsMatchingType(XCUIElementType.searchField);
  XCUIElementQuery get scrollViews =>
      descendantsMatchingType(XCUIElementType.scrollView);
  XCUIElementQuery get scrollBars =>
      descendantsMatchingType(XCUIElementType.scrollBar);
  XCUIElementQuery get staticTexts =>
      descendantsMatchingType(XCUIElementType.staticText);
  XCUIElementQuery get textFields =>
      descendantsMatchingType(XCUIElementType.textField);
  XCUIElementQuery get secureTextFields =>
      descendantsMatchingType(XCUIElementType.secureTextField);
  XCUIElementQuery get datePickers =>
      descendantsMatchingType(XCUIElementType.datePicker);
  XCUIElementQuery get textViews =>
      descendantsMatchingType(XCUIElementType.textView);
  XCUIElementQuery get menus => descendantsMatchingType(XCUIElementType.menu);
  XCUIElementQuery get menuItems =>
      descendantsMatchingType(XCUIElementType.menuItem);
  XCUIElementQuery get menuBars =>
      descendantsMatchingType(XCUIElementType.menuBar);
  XCUIElementQuery get menuBarItems =>
      descendantsMatchingType(XCUIElementType.menuBarItem);
  XCUIElementQuery get maps => descendantsMatchingType(XCUIElementType.map);
  XCUIElementQuery get webViews =>
      descendantsMatchingType(XCUIElementType.webView);
  XCUIElementQuery get steppers =>
      descendantsMatchingType(XCUIElementType.stepper);
  XCUIElementQuery get incrementArrows =>
      descendantsMatchingType(XCUIElementType.incrementArrow);
  XCUIElementQuery get decrementArrows =>
      descendantsMatchingType(XCUIElementType.decrementArrow);
  XCUIElementQuery get tabs => descendantsMatchingType(XCUIElementType.tab);
  XCUIElementQuery get timelines =>
      descendantsMatchingType(XCUIElementType.timeline);
  XCUIElementQuery get ratingIndicators =>
      descendantsMatchingType(XCUIElementType.ratingIndicator);
  XCUIElementQuery get valueIndicators =>
      descendantsMatchingType(XCUIElementType.valueIndicator);
  XCUIElementQuery get splitGroups =>
      descendantsMatchingType(XCUIElementType.splitGroup);
  XCUIElementQuery get splitters =>
      descendantsMatchingType(XCUIElementType.splitter);
  XCUIElementQuery get relevanceIndicators =>
      descendantsMatchingType(XCUIElementType.relevanceIndicator);
  XCUIElementQuery get colorWells =>
      descendantsMatchingType(XCUIElementType.colorWell);
  XCUIElementQuery get helpTags =>
      descendantsMatchingType(XCUIElementType.helpTag);
  XCUIElementQuery get mattes => descendantsMatchingType(XCUIElementType.matte);
  XCUIElementQuery get dockItems =>
      descendantsMatchingType(XCUIElementType.dockItem);
  XCUIElementQuery get rulers => descendantsMatchingType(XCUIElementType.ruler);
  XCUIElementQuery get rulerMarkers =>
      descendantsMatchingType(XCUIElementType.rulerMarker);
  XCUIElementQuery get grids => descendantsMatchingType(XCUIElementType.grid);
  XCUIElementQuery get levelIndicators =>
      descendantsMatchingType(XCUIElementType.levelIndicator);
  XCUIElementQuery get cells => descendantsMatchingType(XCUIElementType.cell);
  XCUIElementQuery get layoutAreas =>
      descendantsMatchingType(XCUIElementType.layoutArea);
  XCUIElementQuery get layoutItems =>
      descendantsMatchingType(XCUIElementType.layoutItem);
  XCUIElementQuery get handles =>
      descendantsMatchingType(XCUIElementType.handle);
  XCUIElementQuery get otherElements =>
      descendantsMatchingType(XCUIElementType.other);
  XCUIElementQuery get statusItems =>
      descendantsMatchingType(XCUIElementType.statusItem);
}

/// `XCUIElementQuery`: a lazy query for elements.
final class XCUIElementQuery with XCUIElementTypeQueryProvider {
  XCUIElementQuery._(this._automation, this._path);

  final XCUIAutomation _automation;

  /// Steps from the application; the agent replays them.
  final List<List<Object?>> _path;

  XCUIElementQuery _query(List<Object?> step) =>
      XCUIElementQuery._(_automation, [..._path, step]);

  XCUIElement _element(List<Object?> step) =>
      XCUIElement._(_automation, [..._path, step]);

  /// The only matching element; resolving it fails unless there's exactly
  /// one.
  XCUIElement get element => _element(['element']);

  @override
  XCUIElement get firstMatch => _element(['firstMatch']);

  XCUIElement elementBoundByIndex(int index) =>
      _element(['elementBoundByIndex', index]);

  XCUIElement elementMatchingPredicate(NSPredicate predicate) =>
      _element(['elementMatchingPredicate', predicate.predicateFormat]);

  XCUIElement elementMatchingType(
    XCUIElementType elementType, [
    String? identifier,
  ]) => _element(['elementMatchingType', elementType.index, identifier]);

  /// `objectForKeyedSubscript:`: the element matching [key] (identifier,
  /// title, label, value or placeholder value).
  XCUIElement operator [](String key) => _element(['subscript', key]);

  @override
  XCUIElementQuery descendantsMatchingType(XCUIElementType type) =>
      _query(['descendantsMatchingType', type.index]);

  XCUIElementQuery childrenMatchingType(XCUIElementType type) =>
      _query(['childrenMatchingType', type.index]);

  XCUIElementQuery matchingPredicate(NSPredicate predicate) =>
      _query(['matchingPredicate', predicate.predicateFormat]);

  XCUIElementQuery matchingType(
    XCUIElementType elementType, [
    String? identifier,
  ]) => _query(['matchingType', elementType.index, identifier]);

  XCUIElementQuery matchingIdentifier(String identifier) =>
      _query(['matchingIdentifier', identifier]);

  XCUIElementQuery containingPredicate(NSPredicate predicate) =>
      _query(['containingPredicate', predicate.predicateFormat]);

  XCUIElementQuery containingType(
    XCUIElementType elementType, [
    String? identifier,
  ]) => _query(['containingType', elementType.index, identifier]);

  /// Evaluates the query.
  Future<int> get count async => (await _call('count')) as int;

  /// The matching elements, each bound to its index.
  Future<List<XCUIElement>> get allElementsBoundByIndex async => [
    for (var i = 0; i < await count; i++) elementBoundByIndex(i),
  ];

  Future<String> get debugDescription async =>
      (await _call('debugDescription')) as String;

  Future<Object?> _call(String method) =>
      _automation._call('XCUIElementQuery.$method', {'query': _path});
}

/// `XCUIElement`: a lazy reference to a UI element, resolved on each use.
///
/// Also has the `XCUIElementAttributes` properties.
class XCUIElement with XCUIElementTypeQueryProvider {
  XCUIElement._(this._automation, this._path);

  final XCUIAutomation _automation;

  /// Steps from the application; the agent replays them.
  final List<List<Object?>> _path;

  @override
  XCUIElementQuery descendantsMatchingType(XCUIElementType type) =>
      XCUIElementQuery._(_automation, [
        ..._path,
        ['descendantsMatchingType', type.index],
      ]);

  XCUIElementQuery childrenMatchingType(XCUIElementType type) =>
      XCUIElementQuery._(_automation, [
        ..._path,
        ['childrenMatchingType', type.index],
      ]);

  /// The element itself.
  @override
  XCUIElement get firstMatch => this;

  /// A point at [normalizedOffset] of the element's frame ((0, 0) is its
  /// top-left corner, (1, 1) its bottom-right one).
  XCUICoordinate coordinateWithNormalizedOffset(CGVector normalizedOffset) =>
      XCUICoordinate._(this, normalizedOffset, const []);

  // Attributes.

  Future<bool> get exists async => (await _call('exists')) as bool;

  Future<bool> get isHittable async => (await _call('isHittable')) as bool;

  Future<String> get identifier async => (await _call('identifier')) as String;

  /// In screen coordinates: points, with the origin at the top-left of the
  /// (primary) screen.
  Future<CGRect> get frame async => _rect(await _call('frame'));

  /// A string, number or null, depending on the element.
  Future<Object?> get value => _call('value');

  Future<String> get title async => (await _call('title')) as String;

  Future<String> get label async => (await _call('label')) as String;

  Future<XCUIElementType> get elementType async =>
      XCUIElementType.values[(await _call('elementType')) as int];

  Future<bool> get isEnabled async => (await _call('isEnabled')) as bool;

  Future<bool> get isSelected async => (await _call('isSelected')) as bool;

  /// iOS only.
  Future<bool> get hasFocus async => (await _call('hasFocus')) as bool;

  Future<String?> get placeholderValue async =>
      (await _call('placeholderValue')) as String?;

  Future<String> get debugDescription async =>
      (await _call('debugDescription')) as String;

  // Waiting.

  Future<bool> waitForExistenceWithTimeout(Duration timeout) async =>
      (await _call('waitForExistenceWithTimeout', {
        'timeout': _seconds(timeout),
      })) as bool;

  Future<bool> waitForNonExistenceWithTimeout(Duration timeout) async =>
      (await _call('waitForNonExistenceWithTimeout', {
        'timeout': _seconds(timeout),
      })) as bool;

  // Input. Touch gestures are iOS only, mouse ones macOS (and iPadOS with a
  // pointer); the agent reports unavailable ones as errors.

  Future<void> typeText(String text) => _call('typeText', {'text': text});

  Future<void> tap() => _call('tap');

  Future<void> doubleTap() => _call('doubleTap');

  Future<void> twoFingerTap() => _call('twoFingerTap');

  Future<void> pressForDuration(Duration duration) =>
      _call('pressForDuration', {'duration': _seconds(duration)});

  Future<void> pressForDurationThenDragToElement(
    Duration duration,
    XCUIElement otherElement,
  ) => _call('pressForDurationThenDragToElement', {
    'duration': _seconds(duration),
    'otherElement': otherElement._path,
  });

  Future<void> swipeUp() => _call('swipeUp');

  Future<void> swipeDown() => _call('swipeDown');

  Future<void> swipeLeft() => _call('swipeLeft');

  Future<void> swipeRight() => _call('swipeRight');

  Future<void> hover() => _call('hover');

  Future<void> click() => _call('click');

  Future<void> doubleClick() => _call('doubleClick');

  Future<void> rightClick() => _call('rightClick');

  Future<void> clickForDurationThenDragToElement(
    Duration duration,
    XCUIElement otherElement,
  ) => _call('clickForDurationThenDragToElement', {
    'duration': _seconds(duration),
    'otherElement': otherElement._path,
  });

  Future<void> scrollByDelta(double deltaX, double deltaY) =>
      _call('scrollByDelta', {'deltaX': deltaX, 'deltaY': deltaY});

  Future<Object?> _call(
    String method, [
    Map<String, Object?> params = const {},
  ]) => _automation._call('XCUIElement.$method', {...params, 'element': _path});
}

/// `XCUIApplication`: a proxy for an app.
final class XCUIApplication extends XCUIElement {
  XCUIApplication._(super._automation, super._path) : super._();

  Future<XCUIApplicationState> get state async =>
      XCUIApplicationState.values[(await _appCall('state')) as int];

  Future<bool> waitForState(
    XCUIApplicationState state,
    Duration timeout,
  ) async => (await _appCall('waitForState', {
    'state': state.index,
    'timeout': _seconds(timeout),
  })) as bool;

  /// Brings the app to the foreground.
  Future<void> activate() => _appCall('activate');

  /// Terminates the app; for the app the test runs in, that ends the test.
  Future<void> terminate() => _appCall('terminate');

  Future<Object?> _appCall(
    String method, [
    Map<String, Object?> params = const {},
  ]) => _automation._call('XCUIApplication.$method', {
    ...params,
    'element': _path,
  });
}

/// `XCUICoordinate`: a lazy screen location, relative to an element.
final class XCUICoordinate {
  XCUICoordinate._(
    this.referencedElement,
    this._normalizedOffset,
    this._offsets,
  );

  final XCUIElement referencedElement;
  final CGVector _normalizedOffset;
  final List<CGVector> _offsets;

  /// A coordinate [offsetVector] points away from this one.
  XCUICoordinate coordinateWithOffset(CGVector offsetVector) =>
      XCUICoordinate._(referencedElement, _normalizedOffset, [
        ..._offsets,
        offsetVector,
      ]);

  /// In screen coordinates, like [XCUIElement.frame].
  Future<CGPoint> get screenPoint async {
    final json = (await _call('screenPoint')) as Map;
    return CGPoint(
      (json['x'] as num).toDouble(),
      (json['y'] as num).toDouble(),
    );
  }

  Future<void> tap() => _call('tap');

  Future<void> doubleTap() => _call('doubleTap');

  Future<void> pressForDuration(Duration duration) =>
      _call('pressForDuration', {'duration': _seconds(duration)});

  Future<void> pressForDurationThenDragToCoordinate(
    Duration duration,
    XCUICoordinate otherCoordinate,
  ) => _call('pressForDurationThenDragToCoordinate', {
    'duration': _seconds(duration),
    'otherCoordinate': otherCoordinate._toJson(),
  });

  Future<void> hover() => _call('hover');

  Future<void> click() => _call('click');

  Future<void> doubleClick() => _call('doubleClick');

  Future<void> rightClick() => _call('rightClick');

  Future<void> clickForDurationThenDragToCoordinate(
    Duration duration,
    XCUICoordinate otherCoordinate,
  ) => _call('clickForDurationThenDragToCoordinate', {
    'duration': _seconds(duration),
    'otherCoordinate': otherCoordinate._toJson(),
  });

  Future<void> scrollByDelta(double deltaX, double deltaY) =>
      _call('scrollByDelta', {'deltaX': deltaX, 'deltaY': deltaY});

  Map<String, Object?> _toJson() => {
    'element': referencedElement._path,
    'normalizedOffset': _normalizedOffset._toJson(),
    'offsets': [for (final offset in _offsets) offset._toJson()],
  };

  Future<Object?> _call(
    String method, [
    Map<String, Object?> params = const {},
  ]) => referencedElement._automation._call('XCUICoordinate.$method', {
    ...params,
    'coordinate': _toJson(),
  });
}

double _seconds(Duration duration) => duration.inMicroseconds / 1e6;

CGRect _rect(Object? json) {
  json as Map;
  return CGRect(
    (json['x'] as num).toDouble(),
    (json['y'] as num).toDouble(),
    (json['width'] as num).toDouble(),
    (json['height'] as num).toDouble(),
  );
}

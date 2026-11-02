#pragma once

#import <Foundation/Foundation.h>

#include "../ph_export.h"

// Thin wrapper over a UIWindow showing a single view that reports touches.
// Like the macOS wrapper, it exposes only what the Dart side needs so that
// ffigen does not have to generate bindings for UIKit.
//
// Must be used on the main thread (flutter_zero runs all Dart code there).

// Calling this through a Dart `@Native` binding is what makes the Dart
// runtime load the native library, which registers the classes below.
PH_EXPORT void ph_ios_init(void);

typedef NS_ENUM(NSInteger, PHTouchPhase) {
  PHTouchPhaseBegan,
  PHTouchPhaseMoved,
  PHTouchPhaseEnded,
  PHTouchPhaseCancelled,
};

// Called for every touch; `x` and `y` are in points, relative to the view.
typedef void (^PHTouchHandler)(PHTouchPhase phase, double x, double y);

// Creates a UIWindow in the app's window scene (once the scene connects, if
// it hasn't yet) and shows it. The app's scene configuration needs no
// delegate or storyboard.
PH_EXPORT
@interface PHUIWindow : NSObject

- (instancetype)init;

@property(nonatomic, copy, nullable) PHTouchHandler touchHandler;

// Accessibility identifier of the window's view; lets UI automation (e.g.
// XCUITest) find it.
@property(nonatomic, copy, nullable) NSString *identifier;

// Hides the window. Also happens on dealloc.
- (void)close;

@end

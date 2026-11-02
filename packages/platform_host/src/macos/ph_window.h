#pragma once

#import <Foundation/Foundation.h>

#include "../ph_export.h"

// Thin wrapper over NSWindow. Exposes only what the Dart side needs so that
// ffigen does not have to generate bindings for the whole AppKit surface.
//
// Must be used on the main thread (flutter_zero runs all Dart code there).
// Calling this through a Dart `@Native` binding is what makes the Dart
// runtime load the native library, which registers the classes below.
PH_EXPORT void ph_macos_init(void);

PH_EXPORT
@interface PHWindow : NSObject

- (instancetype)init;

// Window frame in screen coordinates (origin at bottom-left of the primary
// screen, as in AppKit).
@property(nonatomic) NSRect frame;

@property(nonatomic, copy) NSString *title;

// Accessibility identifier; lets UI automation (e.g. XCUITest) find the
// window independently of its title.
@property(nonatomic, copy, nullable) NSString *identifier;

// Shows the window and makes it the key window.
- (void)makeKeyAndOrderFront;

// Removes the window from the screen. Also happens on dealloc.
- (void)close;

@end

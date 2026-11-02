#import "AppDelegate.h"

@implementation AppDelegate {
  // Headless engine: Dart creates its own windows through platform_host.
  FlutterEngine *_engine;
}

// Windows are created and closed by Dart; closing the last one must not quit
// the app (e.g. between integration tests).
- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
  return NO;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
  // No plugin registration: packages use FFI and native assets instead of
  // platform channel plugins.
  _engine = [[FlutterEngine alloc] initWithName:@"project" project:nil];
  [_engine runWithEntrypoint:nil];
}

- (BOOL)applicationSupportsSecureRestorableState:(NSApplication *)app {
  return YES;
}

@end

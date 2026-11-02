#import "AppDelegate.h"

@implementation AppDelegate {
  // Headless engine: Dart creates its own windows and views through
  // platform_host. The scene in Info.plist deliberately has no delegate or
  // storyboard, so nothing is shown until Dart creates a window.
  FlutterEngine *_engine;
}

- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  // No plugin registration: packages use FFI and native assets instead of
  // platform channel plugins.
  _engine = [[FlutterEngine alloc] initWithName:@"project" project:nil];
  [_engine runWithEntrypoint:nil];
  return [super application:application didFinishLaunchingWithOptions:launchOptions];
}

@end

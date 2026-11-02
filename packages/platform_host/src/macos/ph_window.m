#import "ph_window.h"

#import <AppKit/AppKit.h>

void ph_macos_init(void) {}

@implementation PHWindow {
  NSWindow *_window;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _window = [[NSWindow alloc]
        initWithContentRect:NSMakeRect(0, 0, 800, 600)
                  styleMask:NSWindowStyleMaskTitled |
                            NSWindowStyleMaskClosable |
                            NSWindowStyleMaskMiniaturizable |
                            NSWindowStyleMaskResizable
                    backing:NSBackingStoreBuffered
                      defer:NO];
    // Lifetime is owned by this wrapper (and thus by Dart).
    _window.releasedWhenClosed = NO;
  }
  return self;
}

- (void)dealloc {
  // Don't block: dealloc may run on a finalizer thread.
  NSWindow *window = _window;
  dispatch_async(dispatch_get_main_queue(), ^{
    [window close];
  });
}

- (NSRect)frame {
  return _window.frame;
}

- (void)setFrame:(NSRect)frame {
  [_window setFrame:frame display:YES];
}

- (NSString *)title {
  return _window.title;
}

- (void)setTitle:(NSString *)title {
  _window.title = title;
}

- (NSString *)identifier {
  return _window.accessibilityIdentifier;
}

- (void)setIdentifier:(NSString *)identifier {
  _window.accessibilityIdentifier = identifier;
}

- (void)makeKeyAndOrderFront {
  [_window makeKeyAndOrderFront:nil];
}

- (void)close {
  [_window close];
}

@end

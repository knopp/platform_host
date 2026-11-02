#import "ph_ui_window.h"

#import <UIKit/UIKit.h>

void ph_ios_init(void) {}

@interface PHTouchView : UIView
@property(nonatomic, copy) PHTouchHandler touchHandler;
@end

@implementation PHTouchView

- (void)report:(NSSet<UITouch *> *)touches phase:(PHTouchPhase)phase {
  if (_touchHandler == nil) {
    return;
  }
  for (UITouch *touch in touches) {
    CGPoint location = [touch locationInView:self];
    _touchHandler(phase, location.x, location.y);
  }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [self report:touches phase:PHTouchPhaseBegan];
}

- (void)touchesMoved:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [self report:touches phase:PHTouchPhaseMoved];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [self report:touches phase:PHTouchPhaseEnded];
}

- (void)touchesCancelled:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
  [self report:touches phase:PHTouchPhaseCancelled];
}

@end

static UIWindowScene *PHFirstWindowScene(void) {
  for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
    if ([scene isKindOfClass:[UIWindowScene class]]) {
      return (UIWindowScene *)scene;
    }
  }
  return nil;
}

@implementation PHUIWindow {
  PHTouchView *_view;
  UIWindow *_window;
  id<NSObject> _sceneObserver;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _view = [[PHTouchView alloc] initWithFrame:CGRectZero];
    _view.backgroundColor = UIColor.systemTealColor;

    UIWindowScene *scene = PHFirstWindowScene();
    if (scene != nil) {
      [self showInScene:scene];
    } else {
      // Dart can start before UIKit connects the app's scene.
      __weak PHUIWindow *weakSelf = self;
      _sceneObserver = [NSNotificationCenter.defaultCenter
          addObserverForName:UISceneWillConnectNotification
                      object:nil
                       queue:NSOperationQueue.mainQueue
                  usingBlock:^(NSNotification *notification) {
                    if ([notification.object isKindOfClass:[UIWindowScene class]]) {
                      [weakSelf showInScene:notification.object];
                    }
                  }];
    }
  }
  return self;
}

- (void)showInScene:(UIWindowScene *)scene {
  [self removeSceneObserver];
  if (_view == nil) {
    return;  // Closed before the scene connected.
  }
  UIViewController *controller = [[UIViewController alloc] init];
  controller.view = _view;
  _window = [[UIWindow alloc] initWithWindowScene:scene];
  _window.rootViewController = controller;
  [_window makeKeyAndVisible];
}

- (void)removeSceneObserver {
  if (_sceneObserver != nil) {
    [NSNotificationCenter.defaultCenter removeObserver:_sceneObserver];
    _sceneObserver = nil;
  }
}

- (void)dealloc {
  [self removeSceneObserver];
  // Don't block: dealloc may run on a finalizer thread.
  UIWindow *window = _window;
  dispatch_async(dispatch_get_main_queue(), ^{
    window.hidden = YES;
  });
}

- (PHTouchHandler)touchHandler {
  return _view.touchHandler;
}

- (void)setTouchHandler:(PHTouchHandler)touchHandler {
  _view.touchHandler = touchHandler;
}

- (NSString *)identifier {
  return _view.accessibilityIdentifier;
}

- (void)setIdentifier:(NSString *)identifier {
  _view.accessibilityIdentifier = identifier;
}

- (void)close {
  [self removeSceneObserver];
  _window.hidden = YES;
  _window = nil;
  _view = nil;
}

@end

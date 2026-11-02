#import <TargetConditionals.h>
#import <XCTest/XCTest.h>

// XCUITest agent controlled over a WebSocket; executes the XCUIAutomation
// calls of the Dart mirror (lib/src/xcuitest.dart).
//
// `-testServe` connects to the URL in the PA_AGENT_URL environment variable
// (the Dart test hosts the server; the macOS UI test runner is sandboxed and
// may only make outgoing connections) and executes JSON requests until it
// gets `stop` or the connection closes:
//
//   request:  {"id": 1, "method": "XCUIElement.tap", "params": {...}}
//   response: {"id": 1, "result": <json>} or {"id": 1, "error": "..."}
//
// With PA_AGENT_RECONNECT=1 the agent outlives the app: it keeps connecting
// (until the app's server is up) and serves one session per app launch,
// until it's killed. Otherwise it serves a single session.
//
// Methods are `<class>.<method>`, named after the Objective-C API. Their
// receiver is a param:
//
//   element, query: a path, the steps that lead from an XCUIApplication to
//     the object: [["application", bundleId], ["descendantsMatchingType",
//     4], ["matchingIdentifier", "main"], ["firstMatch"], …]. Like
//     XCUITest's own queries, it's resolved anew for every request.
//   coordinate: {element: path, normalizedOffset: [dx, dy], offsets:
//     [[dx, dy], …]}.
//
// plus `stop`. Times are in seconds; rects are {x, y, width, height} and
// points {x, y}, in XCUIElement screen coordinates.

static NSDictionary *PARectJSON(CGRect rect) {
  return @{
    @"x" : @(rect.origin.x),
    @"y" : @(rect.origin.y),
    @"width" : @(rect.size.width),
    @"height" : @(rect.size.height),
  };
}

static CGVector PAVector(NSArray *json) {
  return CGVectorMake([json[0] doubleValue], [json[1] doubleValue]);
}

static id PANil(id value) { return value == [NSNull null] ? nil : value; }

static XCUIElementType PAType(id value) {
  return (XCUIElementType)[value unsignedIntegerValue];
}

static NSPredicate *PAPredicate(id format) {
  return [NSPredicate predicateWithFormat:format];
}

static void PAUnavailable(NSString *method) {
  [NSException raise:NSInvalidArgumentException
              format:@"%@ is not available on this platform", method];
}

@interface PAAgentServer : XCTestCase
@end

@implementation PAAgentServer {
  NSURLSession *_session;
  NSURLSessionWebSocketTask *_socket;
  NSCondition *_inboxCondition;
  NSMutableArray<NSDictionary *> *_inbox;
  BOOL _closed;

  NSMutableDictionary<NSString *, XCUIApplication *> *_applications;
  // Issues XCUIAutomation reported while handling the current request.
  NSMutableArray<XCTIssue *> *_issues;
}

- (void)testServe {
  // Failures of individual requests are reported back to the client instead
  // of failing (and ending) the test; see -recordIssue:.
  self.continueAfterFailure = YES;

  NSDictionary *environment = NSProcessInfo.processInfo.environment;
  NSString *url = environment[@"PA_AGENT_URL"];
  if (url == nil) {
    [super recordIssue:[[XCTIssue alloc]
                           initWithType:XCTIssueTypeAssertionFailure
                     compactDescription:@"PA_AGENT_URL is not set"]];
    return;
  }
  BOOL reconnect = [environment[@"PA_AGENT_RECONNECT"] isEqual:@"1"];

  _inboxCondition = [[NSCondition alloc] init];
  // The main thread blocks waiting for the session's callbacks, so they must
  // not run at a lower QoS (XCTest reports that as a priority inversion).
  NSOperationQueue *queue = [[NSOperationQueue alloc] init];
  queue.qualityOfService = NSQualityOfServiceUserInteractive;
  _session = [NSURLSession
      sessionWithConfiguration:NSURLSessionConfiguration.defaultSessionConfiguration
                      delegate:nil
                 delegateQueue:queue];

  while (YES) {
    BOOL served = [self serveSessionWithURL:[NSURL URLWithString:url]];
    if (!reconnect) {
      break;
    }
    if (!served) {
      // The app's server isn't up (yet); try again shortly.
      [NSThread sleepForTimeInterval:0.25];
    }
  }
}

// Serves one connection. Returns whether any request was handled.
- (BOOL)serveSessionWithURL:(NSURL *)url {
  [_inboxCondition lock];
  _inbox = [NSMutableArray array];
  _closed = NO;
  [_inboxCondition unlock];
  _applications = [NSMutableDictionary dictionary];

  _socket = [_session webSocketTaskWithURL:url];
  [_socket resume];
  [self receive:_socket];

  BOOL served = NO;
  NSDictionary *request;
  while ((request = [self nextRequest]) != nil) {
    served = YES;
    BOOL stop = [request[@"method"] isEqual:@"stop"];
    [self send:[self handle:request]];
    if (stop) {
      break;
    }
  }
  [_socket cancelWithCloseCode:NSURLSessionWebSocketCloseCodeNormalClosure
                        reason:nil];
  _socket = nil;
  return served;
}

- (void)recordIssue:(XCTIssue *)issue {
  // XCUIAutomation's failures (e.g. "No matches found") aren't reported with
  // the same issue type by every Xcode, so only exempt known diagnostics.
  BOOL failure = issue.type != XCTIssueTypePerformanceRegression;
  if (_issues != nil && failure) {
    [_issues addObject:issue];
  } else if (!failure) {
    // Diagnostics such as performance warnings; log, don't fail the request.
    NSLog(@"PAAgent: (issue type %ld) %@", (long)issue.type, issue.compactDescription);
  } else {
    [super recordIssue:issue];
  }
}

#pragma mark - Transport

- (void)receive:(NSURLSessionWebSocketTask *)socket {
  __weak PAAgentServer *weakSelf = self;
  [socket receiveMessageWithCompletionHandler:^(
              NSURLSessionWebSocketMessage *message, NSError *error) {
    PAAgentServer *agent = weakSelf;
    if (agent == nil) {
      return;
    }
    NSDictionary *request = nil;
    if (message != nil) {
      NSData *data = message.data
                         ?: [message.string dataUsingEncoding:NSUTF8StringEncoding];
      request = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    }
    [agent->_inboxCondition lock];
    // Ignore callbacks from the connection of an earlier session.
    BOOL current = agent->_socket == socket;
    if (current && request != nil) {
      [agent->_inbox addObject:request];
    } else if (current) {
      agent->_closed = YES;
    }
    [agent->_inboxCondition signal];
    [agent->_inboxCondition unlock];
    if (current && request != nil) {
      [agent receive:socket];
    }
  }];
}

// Blocks until a request arrives; nil once the connection is closed.
- (NSDictionary *)nextRequest {
  [_inboxCondition lock];
  while (_inbox.count == 0 && !_closed) {
    [_inboxCondition wait];
  }
  NSDictionary *request = _inbox.firstObject;
  if (request != nil) {
    [_inbox removeObjectAtIndex:0];
  }
  [_inboxCondition unlock];
  return request;
}

- (void)send:(NSDictionary *)response {
  NSData *data = [NSJSONSerialization dataWithJSONObject:response
                                                 options:NSJSONWritingFragmentsAllowed
                                                   error:nil];
  NSString *string = [[NSString alloc] initWithData:data
                                           encoding:NSUTF8StringEncoding];
  dispatch_semaphore_t sent = dispatch_semaphore_create(0);
  [_socket sendMessage:[[NSURLSessionWebSocketMessage alloc]
                           initWithString:string]
      completionHandler:^(NSError *error) {
        dispatch_semaphore_signal(sent);
      }];
  dispatch_semaphore_wait(sent, DISPATCH_TIME_FOREVER);
}

#pragma mark - Requests

- (NSDictionary *)handle:(NSDictionary *)request {
  id requestId = request[@"id"] ?: [NSNull null];
  NSString *method = request[@"method"];
  NSDictionary *params = request[@"params"] ?: @{};

  _issues = [NSMutableArray array];
  id result = nil;
  NSString *error = nil;
  @try {
    result = [self perform:method params:params];
  } @catch (NSException *exception) {
    error = [NSString stringWithFormat:@"%@: %@", exception.name, exception.reason];
  }
  if (error == nil && _issues.count > 0) {
    error = [[_issues valueForKey:@"compactDescription"] componentsJoinedByString:@"\n"];
  }
  _issues = nil;

  if (error != nil) {
    return @{@"id" : requestId, @"error" : error};
  }
  return @{@"id" : requestId, @"result" : result ?: [NSNull null]};
}

- (id)perform:(NSString *)method params:(NSDictionary *)params {
  if ([method isEqual:@"stop"]) {
    return nil;
  }
  NSArray<NSString *> *parts = [method componentsSeparatedByString:@"."];
  if (parts.count == 2) {
    NSString *name = parts[1];
    if ([parts[0] isEqual:@"XCUIElement"]) {
      return [self element:[self element:params[@"element"]] perform:name params:params];
    }
    if ([parts[0] isEqual:@"XCUIApplication"]) {
      return [self application:[self application:params[@"element"]]
                       perform:name
                        params:params];
    }
    if ([parts[0] isEqual:@"XCUIElementQuery"]) {
      return [self query:[self query:params[@"query"]] perform:name];
    }
    if ([parts[0] isEqual:@"XCUICoordinate"]) {
      return [self coordinate:[self coordinate:params[@"coordinate"]]
                      perform:name
                       params:params];
    }
  }
  [NSException raise:NSInvalidArgumentException format:@"Unknown method '%@'", method];
  return nil;
}

- (id)element:(XCUIElement *)element
      perform:(NSString *)method
       params:(NSDictionary *)params {
  // XCUIElementAttributes
  if ([method isEqual:@"exists"]) return @(element.exists);
  if ([method isEqual:@"isHittable"]) return @(element.isHittable);
  if ([method isEqual:@"identifier"]) return element.identifier;
  if ([method isEqual:@"frame"]) return PARectJSON(element.frame);
  if ([method isEqual:@"value"]) return element.value;
  if ([method isEqual:@"title"]) return element.title;
  if ([method isEqual:@"label"]) return element.label;
  if ([method isEqual:@"elementType"]) return @(element.elementType);
  if ([method isEqual:@"isEnabled"]) return @(element.isEnabled);
  if ([method isEqual:@"isSelected"]) return @(element.isSelected);
  if ([method isEqual:@"placeholderValue"]) return element.placeholderValue;
  if ([method isEqual:@"debugDescription"]) return element.debugDescription;
  if ([method isEqual:@"hasFocus"]) {
#if TARGET_OS_OSX
    PAUnavailable(method);
#else
    return @(element.hasFocus);
#endif
  }

  if ([method isEqual:@"waitForExistenceWithTimeout"]) {
    return @([element waitForExistenceWithTimeout:[params[@"timeout"] doubleValue]]);
  }
  if ([method isEqual:@"waitForNonExistenceWithTimeout"]) {
    return @([element waitForNonExistenceWithTimeout:[params[@"timeout"] doubleValue]]);
  }
  if ([method isEqual:@"typeText"]) {
    [element typeText:params[@"text"]];
    return nil;
  }

  NSTimeInterval duration = [params[@"duration"] doubleValue];
#if TARGET_OS_IOS
  // Touch.
  if ([method isEqual:@"tap"]) {
    [element tap];
    return nil;
  }
  if ([method isEqual:@"doubleTap"]) {
    [element doubleTap];
    return nil;
  }
  if ([method isEqual:@"twoFingerTap"]) {
    [element twoFingerTap];
    return nil;
  }
  if ([method isEqual:@"pressForDuration"]) {
    [element pressForDuration:duration];
    return nil;
  }
  if ([method isEqual:@"pressForDurationThenDragToElement"]) {
    [element pressForDuration:duration
            thenDragToElement:[self element:params[@"otherElement"]]];
    return nil;
  }
  if ([method isEqual:@"swipeUp"]) {
    [element swipeUp];
    return nil;
  }
  if ([method isEqual:@"swipeDown"]) {
    [element swipeDown];
    return nil;
  }
  if ([method isEqual:@"swipeLeft"]) {
    [element swipeLeft];
    return nil;
  }
  if ([method isEqual:@"swipeRight"]) {
    [element swipeRight];
    return nil;
  }
#endif
  // Pointer.
  if ([method isEqual:@"hover"]) {
    [element hover];
    return nil;
  }
  if ([method isEqual:@"click"]) {
    [element click];
    return nil;
  }
  if ([method isEqual:@"doubleClick"]) {
    [element doubleClick];
    return nil;
  }
  if ([method isEqual:@"rightClick"]) {
    [element rightClick];
    return nil;
  }
  if ([method isEqual:@"clickForDurationThenDragToElement"]) {
    [element clickForDuration:duration
            thenDragToElement:[self element:params[@"otherElement"]]];
    return nil;
  }
  if ([method isEqual:@"scrollByDelta"]) {
    [element scrollByDeltaX:[params[@"deltaX"] doubleValue]
                     deltaY:[params[@"deltaY"] doubleValue]];
    return nil;
  }
  return [self unknown:method of:@"XCUIElement"];
}

- (id)application:(XCUIApplication *)application
          perform:(NSString *)method
           params:(NSDictionary *)params {
  if ([method isEqual:@"state"]) return @(application.state);
  if ([method isEqual:@"waitForState"]) {
    return @([application waitForState:[params[@"state"] unsignedIntegerValue]
                                timeout:[params[@"timeout"] doubleValue]]);
  }
  if ([method isEqual:@"activate"]) {
    [application activate];
    return nil;
  }
  if ([method isEqual:@"terminate"]) {
    [application terminate];
    return nil;
  }
  return [self unknown:method of:@"XCUIApplication"];
}

- (id)query:(XCUIElementQuery *)query perform:(NSString *)method {
  if ([method isEqual:@"count"]) return @(query.count);
  if ([method isEqual:@"debugDescription"]) return query.debugDescription;
  return [self unknown:method of:@"XCUIElementQuery"];
}

- (id)coordinate:(XCUICoordinate *)coordinate
         perform:(NSString *)method
          params:(NSDictionary *)params {
  if ([method isEqual:@"screenPoint"]) {
    CGPoint point = coordinate.screenPoint;
    return @{@"x" : @(point.x), @"y" : @(point.y)};
  }

  NSTimeInterval duration = [params[@"duration"] doubleValue];
#if TARGET_OS_IOS
  // Touch.
  if ([method isEqual:@"tap"]) {
    [coordinate tap];
    return nil;
  }
  if ([method isEqual:@"doubleTap"]) {
    [coordinate doubleTap];
    return nil;
  }
  if ([method isEqual:@"pressForDuration"]) {
    [coordinate pressForDuration:duration];
    return nil;
  }
  if ([method isEqual:@"pressForDurationThenDragToCoordinate"]) {
    [coordinate pressForDuration:duration
            thenDragToCoordinate:[self coordinate:params[@"otherCoordinate"]]];
    return nil;
  }
#endif
  // Pointer.
  if ([method isEqual:@"hover"]) {
    [coordinate hover];
    return nil;
  }
  if ([method isEqual:@"click"]) {
    [coordinate click];
    return nil;
  }
  if ([method isEqual:@"doubleClick"]) {
    [coordinate doubleClick];
    return nil;
  }
  if ([method isEqual:@"rightClick"]) {
    [coordinate rightClick];
    return nil;
  }
  if ([method isEqual:@"clickForDurationThenDragToCoordinate"]) {
    [coordinate clickForDuration:duration
            thenDragToCoordinate:[self coordinate:params[@"otherCoordinate"]]];
    return nil;
  }
  if ([method isEqual:@"scrollByDelta"]) {
    [coordinate scrollByDeltaX:[params[@"deltaX"] doubleValue]
                        deltaY:[params[@"deltaY"] doubleValue]];
    return nil;
  }
  return [self unknown:method of:@"XCUICoordinate"];
}

// Methods that exist, but not on this platform, are reported as such.
- (id)unknown:(NSString *)method of:(NSString *)className {
  static NSSet<NSString *> *known;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    known = [NSSet setWithArray:@[
      @"tap", @"doubleTap", @"twoFingerTap", @"pressForDuration",
      @"pressForDurationThenDragToElement", @"pressForDurationThenDragToCoordinate",
      @"swipeUp", @"swipeDown", @"swipeLeft", @"swipeRight"
    ]];
  });
  if ([known containsObject:method]) {
    PAUnavailable([NSString stringWithFormat:@"%@.%@", className, method]);
  }
  [NSException raise:NSInvalidArgumentException
              format:@"Unknown method '%@.%@'", className, method];
  return nil;
}

#pragma mark - Receivers

// Replays a path (see the top of the file).
- (id)resolve:(NSArray<NSArray *> *)path {
  if (![path isKindOfClass:[NSArray class]] || path.count == 0) {
    [NSException raise:NSInvalidArgumentException format:@"Invalid path %@", path];
  }
  id object = nil;
  for (NSArray *step in path) {
    NSString *op = step[0];
    id arg = step.count > 1 ? PANil(step[1]) : nil;
    id arg2 = step.count > 2 ? PANil(step[2]) : nil;
    if (object == nil) {
      if (![op isEqual:@"application"]) {
        [NSException raise:NSInvalidArgumentException
                    format:@"A path starts with an application, not '%@'", op];
      }
      XCUIApplication *application = _applications[arg];
      if (application == nil) {
        // Attaches to the running app; does not launch it.
        application = [[XCUIApplication alloc] initWithBundleIdentifier:arg];
        _applications[arg] = application;
      }
      object = application;
    } else if ([op isEqual:@"descendantsMatchingType"]) {
      object = [object descendantsMatchingType:PAType(arg)];
    } else if ([op isEqual:@"childrenMatchingType"]) {
      object = [object childrenMatchingType:PAType(arg)];
    } else if ([op isEqual:@"matchingIdentifier"]) {
      object = [object matchingIdentifier:arg];
    } else if ([op isEqual:@"matchingType"]) {
      object = [object matchingType:PAType(arg) identifier:arg2];
    } else if ([op isEqual:@"matchingPredicate"]) {
      object = [object matchingPredicate:PAPredicate(arg)];
    } else if ([op isEqual:@"containingType"]) {
      object = [object containingType:PAType(arg) identifier:arg2];
    } else if ([op isEqual:@"containingPredicate"]) {
      object = [object containingPredicate:PAPredicate(arg)];
    } else if ([op isEqual:@"element"]) {
      object = [object element];
    } else if ([op isEqual:@"firstMatch"]) {
      object = [object firstMatch];
    } else if ([op isEqual:@"elementBoundByIndex"]) {
      object = [object elementBoundByIndex:[arg unsignedIntegerValue]];
    } else if ([op isEqual:@"elementMatchingType"]) {
      object = [object elementMatchingType:PAType(arg) identifier:arg2];
    } else if ([op isEqual:@"elementMatchingPredicate"]) {
      object = [object elementMatchingPredicate:PAPredicate(arg)];
    } else if ([op isEqual:@"subscript"]) {
      object = object[arg];
    } else {
      [NSException raise:NSInvalidArgumentException format:@"Unknown path step '%@'", op];
    }
  }
  return object;
}

- (XCUIElement *)element:(NSArray *)path {
  id object = [self resolve:path];
  if (![object isKindOfClass:[XCUIElement class]]) {
    [NSException raise:NSInvalidArgumentException format:@"Not an element: %@", path];
  }
  return object;
}

- (XCUIApplication *)application:(NSArray *)path {
  id object = [self resolve:path];
  if (![object isKindOfClass:[XCUIApplication class]]) {
    [NSException raise:NSInvalidArgumentException format:@"Not an application: %@", path];
  }
  return object;
}

- (XCUIElementQuery *)query:(NSArray *)path {
  id object = [self resolve:path];
  if (![object isKindOfClass:[XCUIElementQuery class]]) {
    [NSException raise:NSInvalidArgumentException format:@"Not a query: %@", path];
  }
  return object;
}

- (XCUICoordinate *)coordinate:(NSDictionary *)json {
  XCUICoordinate *coordinate = [[self element:json[@"element"]]
      coordinateWithNormalizedOffset:PAVector(json[@"normalizedOffset"])];
  for (NSArray *offset in json[@"offsets"]) {
    coordinate = [coordinate coordinateWithOffset:PAVector(offset)];
  }
  return coordinate;
}

@end

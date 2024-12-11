
#import <AppMetricaWebKit/AppMetricaWebKit.h>

#if !TARGET_OS_TV
#import <AppMetricaLog/AppMetricaLog.h>
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import <WebKit/WebKit.h>
#import "AMAWebKitLogging.h"

static NSString *const kAMAAddJsInterfaceScript = @""
    "if (typeof(AppMetrica) === 'undefined') {"
        "window.AppMetrica = {"
            "reportEvent: function(eventName, eventValue) {"
                "window.webkit.messageHandlers.appmetrica_reportEvent.postMessage({'name': eventName, 'value': eventValue});"
            "}"
        "}"
    "}"
    "if (typeof(AppMetricaInitializer) === 'undefined') {"
        "window.AppMetricaInitializer = {"
            "init: function(value) {"
                "window.webkit.messageHandlers.appmetricaInitializer_init.postMessage({'value': value});"
            "}"
        "}"
    "}";
static NSString *const kAMAAppMetricaScriptMessageName = @"appmetrica_reportEvent";
static NSString *const kAMAAppMetricaInitializerScriptMessageName = @"appmetricaInitializer_init";
static NSString *const kAMAKeyEventName = @"name";
static NSString *const kAMAKeyEventValue = @"value";

@interface AMAJSController ()

@property (nonatomic, strong, readwrite) WKUserContentController *userContentController;

@property(nonatomic, strong) id<AMAAsyncExecuting> executor;
@property(atomic, strong) id<AMAJSReporting> reporter;

@end


@implementation AMAJSController

- (instancetype)initWithUserContentController:(WKUserContentController *)userContentController
{
    self = [super init];
    if (self != nil) {
        _userContentController = userContentController;
    }
    return self;
}

- (void)setUpWebViewReporting:(id<AMAAsyncExecuting>)executor
                 withReporter:(id<AMAJSReporting>)reporter
{
    AMALogInfo(@"Setting up web view reporting");
    self.reporter = reporter;
    self.executor = executor;
    [self.userContentController addScriptMessageHandler:self name:kAMAAppMetricaScriptMessageName];
    [self.userContentController addScriptMessageHandler:self name:kAMAAppMetricaInitializerScriptMessageName];
    [self.userContentController addUserScript:[[self class] addInterfaceScript]];
}

#pragma mark - WKScriptMessageHandler

- (void)userContentController:(WKUserContentController *)userContentController
      didReceiveScriptMessage:(WKScriptMessage *)message
{
    AMALogInfo(@"Message name: %@, value: %@", message.name, message.body);
    // reporter should not be nil because it is set in setUpWebViewReporting
    if ([message.name isEqual:kAMAAppMetricaScriptMessageName]) {
        id eventName = message.body[kAMAKeyEventName];
        id eventValue = message.body[kAMAKeyEventValue];
        if (eventName == nil || [eventName isKindOfClass:[NSString class]]) {
            NSString *stringValue = nil;
            if ([eventValue isKindOfClass:[NSString class]]) {
                stringValue = eventValue;
            }
            [self execute:^{
                [self.reporter reportJSEvent:eventName value:stringValue];
            }];
        } else {
            AMALogWarn(@"Invalid parameter types: %@", message.body);
        }
    }
    else if ([message.name isEqual:kAMAAppMetricaInitializerScriptMessageName]) {
        id value = message.body[kAMAKeyEventValue];
        if (value == nil || [value isKindOfClass:[NSString class]]) {
            [self execute:^{
                [self.reporter reportJSInitEvent:value];
            }];
        } else {
            AMALogWarn(@"Invalid parameter types: %@", message.body);
        }
    }
}

- (void)execute:(dispatch_block_t)block
{
    [self.executor execute:^{
        block();
    }];
}

#pragma mark - Private

+ (WKUserScript *)addInterfaceScript
{
    static dispatch_once_t onceToken;
    static WKUserScript *addInterfaceScript = nil;
    dispatch_once(&onceToken, ^{
        addInterfaceScript = [[WKUserScript alloc] initWithSource:kAMAAddJsInterfaceScript
                                                    injectionTime:WKUserScriptInjectionTimeAtDocumentStart
                                                 forMainFrameOnly:NO];
    });
    return addInterfaceScript;
}


@end
#endif

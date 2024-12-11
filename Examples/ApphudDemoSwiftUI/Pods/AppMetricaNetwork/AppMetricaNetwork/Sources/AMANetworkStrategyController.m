
#import "AMANetworkCore.h"
#import <AppMetricaNetwork/AppMetricaNetwork.h>

@interface AMANetworkStrategyController ()

@property (nonatomic, strong, readwrite) id<AMANetworkSessionProviding> registeredSessionProvider;
@property (nonatomic, strong, readonly) AMAHTTPSessionProvider *defaultSessionProvider;

@end

@implementation AMANetworkStrategyController

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _registeredSessionProvider = nil;
        _defaultSessionProvider = [[AMAHTTPSessionProvider alloc] init];
    }
    return self;
}

+ (void)initialize
{
    if (self == [AMANetworkStrategyController class]) {
        [[[self class] logConfigurator] setupLogWithChannel:AMA_LOG_CHANNEL];
        [[[self class] logConfigurator] setChannel:AMA_LOG_CHANNEL enabled:NO];
    }
}

- (void)registerSessionProvider:(id<AMANetworkSessionProviding>)sessionProvider
{
    @synchronized (self) {
        self.registeredSessionProvider = sessionProvider;
    }
}

- (id<AMANetworkSessionProviding>)sessionProvider
{
    @synchronized (self) {
        if (self.registeredSessionProvider != nil) {
            return self.registeredSessionProvider;
        }
        else {
            return self.defaultSessionProvider;
        }
    }
}

+ (AMALogConfigurator *)logConfigurator
{
    static AMALogConfigurator *logConfigurator = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @autoreleasepool {
            logConfigurator = [AMALogConfigurator new];
        }
    });
    return logConfigurator;
}

+ (instancetype)sharedInstance
{
    static AMANetworkStrategyController *controller = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        controller = [[[self class] alloc] init];
    });
    return controller;
}

@end

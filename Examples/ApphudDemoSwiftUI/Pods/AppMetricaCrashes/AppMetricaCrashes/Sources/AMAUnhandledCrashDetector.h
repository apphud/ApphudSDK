
#import <Foundation/Foundation.h>
#import <AppMetricaHostState/AppMetricaHostState.h>
#import "AMACrashLogging.h"

@class AMAUserDefaultsStorage;
@protocol AMAAsyncExecuting;

typedef NS_ENUM(NSInteger, AMAUnhandledCrashType) {
    AMAUnhandledCrashUnknown,
    AMAUnhandledCrashBackground,
    AMAUnhandledCrashForeground,
};

typedef void (^AMAUnhandledCrashCallback)(AMAUnhandledCrashType crashType);

@interface AMAUnhandledCrashDetector : NSObject<AMAHostStateProviderDelegate>

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithStorage:(AMAUserDefaultsStorage *)storage
                       executor:(id<AMAAsyncExecuting>)executor;

- (instancetype)initWithStorage:(AMAUserDefaultsStorage *)storage
              hostStateProvider:(id<AMAHostStateProviding>)hostStateProvider
                       executor:(id<AMAAsyncExecuting>)executor NS_DESIGNATED_INITIALIZER;

- (void)startDetecting;

- (void)checkUnhandledCrash:(AMAUnhandledCrashCallback)unhandledCrashCallback;

@end

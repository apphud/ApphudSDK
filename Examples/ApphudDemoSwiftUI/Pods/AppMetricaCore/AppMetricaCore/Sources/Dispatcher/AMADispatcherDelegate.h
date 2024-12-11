
#import <Foundation/Foundation.h>

@class AMADispatcher;

extern NSString *const kAMADispatcherErrorDomain;
extern NSString *const kAMADispatcherErrorApiKeyUserInfoKey;

typedef NS_ENUM(NSInteger, AMADispatcherReportErrorCode) {
    AMADispatcherReportErrorNoHosts,
    AMADispatcherReportErrorNoDeviceId,
    AMADispatcherReportErrorNetwork,
    AMADispatcherReportErrorDataSendingForbidden,
    AMADispatcherReportErrorNoNetworkAvailiable,
    AMADispatcherReportErrorDidNotCheckInitialAttribution,
};

@protocol AMADispatcherDelegate <NSObject>

- (void)dispatcherDidPerformReport:(AMADispatcher *)dispatcher;
- (void)dispatcher:(AMADispatcher *)dispatcher didFailToReportWithError:(NSError *)error;

@optional
- (void)dispatcherWillFinishDispatching:(AMADispatcher *)dispatcher;

@end

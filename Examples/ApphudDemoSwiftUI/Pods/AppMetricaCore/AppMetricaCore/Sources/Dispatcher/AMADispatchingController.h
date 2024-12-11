
#import <Foundation/Foundation.h>

@class AMAReporterStorage;
@class AMAPersistentTimeoutConfiguration;
@protocol AMADispatcherDelegate;

@interface AMADispatchingController : NSObject

@property (nonatomic, weak) id<AMADispatcherDelegate> proxyDelegate;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithTimeoutConfiguration:(AMAPersistentTimeoutConfiguration *)timeoutConfiguration;

- (void)registerDispatcherWithReporterStorage:(AMAReporterStorage *)reporterStorage main:(BOOL)main;

- (void)performReportForApiKey:(NSString *)apiKey forced:(BOOL)forced;

- (void)start;
- (void)shutdown;

@end

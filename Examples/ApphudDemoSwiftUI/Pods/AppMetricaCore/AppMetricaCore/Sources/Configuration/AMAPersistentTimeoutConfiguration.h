
#import <Foundation/Foundation.h>

@class AMATimeoutConfiguration;
@protocol AMAKeyValueStoring;

typedef NSString *AMAHostType;

extern AMAHostType const AMAStartupHostType;
extern AMAHostType const AMAReportHostType;
extern AMAHostType const AMALocationHostType;
extern AMAHostType const AMATrackingHostType;

@interface AMAPersistentTimeoutConfiguration : NSObject

@property (nonatomic, strong, readonly) id<AMAKeyValueStoring> storage;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithStorage:(id<AMAKeyValueStoring>)storage;

- (AMATimeoutConfiguration *)timeoutConfigForHostType:(AMAHostType)hostType;
- (void)saveTimeoutConfig:(AMATimeoutConfiguration *)timeoutItem forHostType:(AMAHostType)hostType;

@end


#import <Foundation/Foundation.h>
#import "AMAEventTypes.h"

@class AMAEvent;

@interface AMAEventLogger : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithApiKey:(NSString *)apiKey;

- (void)logClientEventReceivedWithName:(NSString *)name parameters:(NSDictionary *)parameters;
- (void)logProfileEventReceived;
- (void)logRevenueEventReceived;
- (void)logECommerceEventReceived;
- (void)logAdRevenueEventReceived;

- (void)logEventBuilt:(AMAEvent *)event;
- (void)logEventSaved:(AMAEvent *)event;
- (void)logEventPurged:(AMAEvent *)event;
- (void)logEventSent:(AMAEvent *)event;

+ (instancetype)sharedInstanceForApiKey:(NSString *)apiKey;

@end

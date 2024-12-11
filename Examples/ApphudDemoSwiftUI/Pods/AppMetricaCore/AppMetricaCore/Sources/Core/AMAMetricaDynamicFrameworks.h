
#import "AMAFramework.h"

@interface AMAMetricaDynamicFrameworks : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (AMAFramework *)sServices;
+ (AMAFramework *)adServices;
+ (AMAFramework *)sConfiguration;
+ (AMAFramework *)storeKit;

@end

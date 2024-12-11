
#import "AMALogMiddleware.h"

NS_AVAILABLE_IOS(10_0)
@interface AMAOSLogMiddleware : NSObject <AMALogMiddleware>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithCategory:(const char *)category;

@end

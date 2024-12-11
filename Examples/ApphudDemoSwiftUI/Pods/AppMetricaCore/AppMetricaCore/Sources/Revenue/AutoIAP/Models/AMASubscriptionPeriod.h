
#import <Foundation/Foundation.h>
#import "AMAPurchasesDefines.h"

@interface AMASubscriptionPeriod : NSObject

@property (nonatomic, assign, readonly) NSUInteger count;
@property (nonatomic, assign, readonly) AMATimeUnit timeUnit;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithCount:(NSUInteger)count timeUnit:(AMATimeUnit)timeUnit;

@end

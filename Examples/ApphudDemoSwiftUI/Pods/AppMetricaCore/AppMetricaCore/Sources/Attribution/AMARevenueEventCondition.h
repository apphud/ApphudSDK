
#import <Foundation/Foundation.h>
#import "AMAJSONSerializable.h"
#import "AMARevenueSource.h"

@interface AMARevenueEventCondition : NSObject <AMAJSONSerializable>

- (instancetype)initWithSource:(AMARevenueSource)source;
- (BOOL)checkEvent:(BOOL)isAuto;

@end

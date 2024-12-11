
#import <Foundation/Foundation.h>
#import "AMAECommerce+Internal.h"
#import "AMAJSONSerializable.h"

@interface AMAECommerceEventCondition : NSObject <AMAJSONSerializable>

- (instancetype)initWithType:(AMAECommerceEventType)type;
- (BOOL)checkEvent:(AMAECommerceEventType)type;

@end

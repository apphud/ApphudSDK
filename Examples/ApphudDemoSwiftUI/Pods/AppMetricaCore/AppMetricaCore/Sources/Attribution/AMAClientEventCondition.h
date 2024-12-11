
#import <Foundation/Foundation.h>
#import "AMAJSONSerializable.h"

@interface AMAClientEventCondition : NSObject <AMAJSONSerializable>

- (instancetype)initWithName:(NSString *)eventName;
- (BOOL)checkEvent:(NSString *)name;

@end


#import <Foundation/Foundation.h>
#import "AMAAttributeUpdateValidating.h"

typedef void (^AMAProhibitingAttributeUpdateLogBlock)(AMAAttributeUpdate *update);

@interface AMAProhibitingAttributeUpdateValidator : NSObject <AMAAttributeUpdateValidating>

- (instancetype)initWithLogBlock:(AMAProhibitingAttributeUpdateLogBlock)logBlock;

@end


#import <Foundation/Foundation.h>
#import "AMAAttributeUpdateValidating.h"

@interface AMAAttributeUpdateCountValidator : NSObject <AMAAttributeUpdateValidating>

- (instancetype)initWithCountLimit:(NSUInteger)countLimit;

@end

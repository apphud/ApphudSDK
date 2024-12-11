
#import <Foundation/Foundation.h>
#import "AMAAttributeUpdateValidating.h"

@interface AMAAttributeUpdateNameLengthValidator : NSObject <AMAAttributeUpdateValidating>

- (instancetype)initWithLengthLimit:(NSUInteger)lengthLimit;

@end

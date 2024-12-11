
#import <Foundation/Foundation.h>
#import "AMAAttributeUpdateValidating.h"

@interface AMAAttributeUpdateNamePrefixValidator : NSObject <AMAAttributeUpdateValidating>

- (instancetype)initWithForbiddenPrefix:(NSString *)forbiddenPrefix;

@end

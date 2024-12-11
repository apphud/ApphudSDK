
#import "AMAUserProfileUpdate.h"
#import "AMAAttributeUpdateValidating.h"

@implementation AMAUserProfileUpdate

- (instancetype)initWithAttributeUpdate:(AMAAttributeUpdate *)attributeUpdate
                             validators:(NSArray<id<AMAAttributeUpdateValidating>> *)validators
{
    self = [super init];
    if (self != nil) {
        _attributeUpdate = attributeUpdate;
        _validators = validators;
    }
    return self;
}

@end

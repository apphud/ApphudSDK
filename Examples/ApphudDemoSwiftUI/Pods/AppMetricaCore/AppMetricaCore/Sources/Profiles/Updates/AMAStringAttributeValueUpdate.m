
#import "AMACore.h"
#import "AMAStringAttributeValueUpdate.h"
#import "AMAAttributeValue.h"

@interface AMAStringAttributeValueUpdate ()

@property (nonatomic, copy, readonly) NSString *value;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> truncator;

@end

@implementation AMAStringAttributeValueUpdate

- (instancetype)initWithValue:(NSString *)value truncator:(id<AMAStringTruncating>)truncator
{
    self = [super init];
    if (self != nil) {
        _value = [value copy];
        _truncator = truncator;
    }
    return self;
}

- (void)applyToValue:(AMAAttributeValue *)value
{
    value.stringValue = [self.truncator truncatedString:self.value onTruncation:nil];
}

@end

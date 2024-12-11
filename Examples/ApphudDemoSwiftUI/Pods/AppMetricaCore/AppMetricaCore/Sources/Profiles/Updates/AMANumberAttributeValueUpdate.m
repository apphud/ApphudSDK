
#import "AMANumberAttributeValueUpdate.h"
#import "AMAAttributeValue.h"

@interface AMANumberAttributeValueUpdate ()

@property (nonatomic, assign, readonly) double value;

@end

@implementation AMANumberAttributeValueUpdate

- (instancetype)initWithValue:(double)value
{
    self = [super init];
    if (self != nil) {
        _value = value;
    }
    return self;
}

- (void)applyToValue:(AMAAttributeValue *)value
{
    value.numberValue = @(self.value);
}

@end

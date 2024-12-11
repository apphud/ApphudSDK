
#import "AMABoolAttributeValueUpdate.h"
#import "AMAAttributeValue.h"

@interface AMABoolAttributeValueUpdate ()

@property (nonatomic, assign, readonly) BOOL value;

@end

@implementation AMABoolAttributeValueUpdate

- (instancetype)initWithValue:(BOOL)value
{
    self = [super init];
    if (self != nil) {
        _value = value;
    }
    return self;
}

- (void)applyToValue:(AMAAttributeValue *)value
{
    value.boolValue = @(self.value);
}

@end

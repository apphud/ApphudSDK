
#import "AMACounterAttributeValueUpdate.h"
#import "AMAAttributeValue.h"

@interface AMACounterAttributeValueUpdate ()

@property (nonatomic, assign, readonly) double deltaValue;

@end

@implementation AMACounterAttributeValueUpdate

- (instancetype)initWithDeltaValue:(double)deltaValue
{
    self = [super init];
    if (self != nil) {
        _deltaValue = deltaValue;
    }
    return self;
}

- (void)applyToValue:(AMAAttributeValue *)value
{
    value.counterValue = @([value.counterValue doubleValue] + self.deltaValue);
}

@end

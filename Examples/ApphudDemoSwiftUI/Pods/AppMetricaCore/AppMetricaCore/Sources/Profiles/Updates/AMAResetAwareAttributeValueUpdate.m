
#import "AMAResetAwareAttributeValueUpdate.h"
#import "AMAAttributeValue.h"

@interface AMAResetAwareAttributeValueUpdate ()

@property (nonatomic, assign, readonly) BOOL reset;
@property (nonatomic, strong, readonly) id<AMAAttributeValueUpdate> underlyingValueUpdate;

@end

@implementation AMAResetAwareAttributeValueUpdate

- (instancetype)initWithIsReset:(BOOL)isReset
          underlyingValueUpdate:(id<AMAAttributeValueUpdate>)underlyingValueUpdate
{
    self = [super init];
    if (self != nil) {
        _reset = isReset;
        _underlyingValueUpdate = underlyingValueUpdate;
    }
    return self;
}

- (void)resetValuesOfAttributeValue:(AMAAttributeValue *)attributeValue
{
    attributeValue.stringValue = nil;
    attributeValue.numberValue = nil;
    attributeValue.counterValue = nil;
    attributeValue.boolValue = nil;
}

- (void)applyToValue:(AMAAttributeValue *)value
{
    value.reset = @(self.reset);
    if (self.reset) {
        [self resetValuesOfAttributeValue:value];
    }
    else {
        [self.underlyingValueUpdate applyToValue:value];
    }
}

@end

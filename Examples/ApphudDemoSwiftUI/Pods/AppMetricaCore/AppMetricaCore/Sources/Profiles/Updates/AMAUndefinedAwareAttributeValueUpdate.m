
#import "AMAUndefinedAwareAttributeValueUpdate.h"
#import "AMAAttributeValue.h"

@interface AMAUndefinedAwareAttributeValueUpdate ()

@property (nonatomic, assign, readonly) BOOL undefined;
@property (nonatomic, strong, readonly) id<AMAAttributeValueUpdate> underlyingValueUpdate;

@end

@implementation AMAUndefinedAwareAttributeValueUpdate

- (instancetype)initWithIsUndefined:(BOOL)isUndefined
              underlyingValueUpdate:(id<AMAAttributeValueUpdate>)underlyingValueUpdate
{
    self = [super init];
    if (self != nil) {
        _undefined = isUndefined;
        _underlyingValueUpdate = underlyingValueUpdate;
    }
    return self;
}

- (BOOL)isValueUndefined:(AMAAttributeValue *)value
{
    BOOL undefined = YES;
    undefined = undefined && value.stringValue == nil;
    undefined = undefined && value.numberValue == nil;
    undefined = undefined && value.counterValue == nil;
    undefined = undefined && value.boolValue == nil;
    return undefined;
}

- (void)applyToValue:(AMAAttributeValue *)value
{
    if (self.undefined == NO || [self isValueUndefined:value]) {
        value.setIfUndefined = @(self.undefined);
        [self.underlyingValueUpdate applyToValue:value];
    }
}

@end

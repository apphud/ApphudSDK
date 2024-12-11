
#import "AMACategoricalAttributeValueUpdateFactory.h"
#import "AMAUndefinedAwareAttributeValueUpdate.h"
#import "AMAResetAwareAttributeValueUpdate.h"

@implementation AMACategoricalAttributeValueUpdateFactory

- (id<AMAAttributeValueUpdate>)updateWithUnderlyingUpdate:(id<AMAAttributeValueUpdate>)underlyingUpdate
                                                  isReset:(BOOL)isReset
                                              isUndefined:(BOOL)isUndefined
{
    id<AMAAttributeValueUpdate> resetAwareUpdate =
        [[AMAResetAwareAttributeValueUpdate alloc] initWithIsReset:isReset
                                             underlyingValueUpdate:underlyingUpdate];
    id<AMAAttributeValueUpdate> undefinedAwareUpdate =
        [[AMAUndefinedAwareAttributeValueUpdate alloc] initWithIsUndefined:isUndefined
                                                     underlyingValueUpdate:resetAwareUpdate];
    return undefinedAwareUpdate;
}

- (id<AMAAttributeValueUpdate>)updateWithUnderlyingUpdate:(id<AMAAttributeValueUpdate>)underlyingUpdate
{
    return [self updateWithUnderlyingUpdate:underlyingUpdate isReset:NO isUndefined:NO];
}

- (id<AMAAttributeValueUpdate>)updateForUndefinedWithUnderlyingUpdate:(id<AMAAttributeValueUpdate>)underlyingUpdate
{
    return [self updateWithUnderlyingUpdate:underlyingUpdate isReset:NO isUndefined:YES];
}

- (id<AMAAttributeValueUpdate>)updateWithReset
{
    return [self updateWithUnderlyingUpdate:nil isReset:YES isUndefined:NO];
}

@end

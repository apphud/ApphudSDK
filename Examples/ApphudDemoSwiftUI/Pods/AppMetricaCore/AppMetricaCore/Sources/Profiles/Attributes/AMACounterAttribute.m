
#import "AMACounterAttribute.h"
#import "AMAAttributeUpdate.h"
#import "AMACounterAttributeValueUpdate.h"
#import "AMAUserProfileUpdateProviding.h"

@interface AMACounterAttribute ()

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, strong, readonly) id<AMAUserProfileUpdateProviding> userProfileUpdateProvider;

@end

@implementation AMACounterAttribute

- (instancetype)initWithName:(NSString *)name
   userProfileUpdateProvider:(id<AMAUserProfileUpdateProviding>)userProfileUpdateProvider
{
    self = [super init];
    if (self != nil) {
        _name = [name copy];
        _userProfileUpdateProvider = userProfileUpdateProvider;
    }
    return self;
}

- (AMAUserProfileUpdate *)withDelta:(double)value
{
    id<AMAAttributeValueUpdate> update = [[AMACounterAttributeValueUpdate alloc] initWithDeltaValue:value];
    return [self.userProfileUpdateProvider updateWithAttributeName:self.name
                                                              type:AMAAttributeTypeCounter
                                                       valueUpdate:update];
}

@end

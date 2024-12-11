
#import "AMAStringAttribute.h"
#import "AMAAttributeUpdate.h"
#import "AMAStringAttributeValueUpdate.h"
#import "AMACategoricalAttributeValueUpdateFactory.h"
#import "AMAUserProfileUpdateProviding.h"
#import "AMAStringAttributeTruncationProvider.h"

@interface AMAStringAttribute ()

@property (nonatomic, strong, readonly) id<AMAUserProfileUpdateProviding> userProfileUpdateProvider;
@property (nonatomic, strong, readonly) AMAStringAttributeTruncationProvider *truncationProvider;
@property (nonatomic, strong, readonly) AMACategoricalAttributeValueUpdateFactory *categoricalUpdateFactory;

@end

@implementation AMAStringAttribute

- (instancetype)initWithName:(NSString *)name
   userProfileUpdateProvider:(id<AMAUserProfileUpdateProviding>)userProfileUpdateProvider
          truncationProvider:(AMAStringAttributeTruncationProvider *)truncationProvider
{
    return [self initWithName:name
    userProfileUpdateProvider:userProfileUpdateProvider
           truncationProvider:truncationProvider
     categoricalUpdateFactory:[[AMACategoricalAttributeValueUpdateFactory alloc] init]];
}

- (instancetype)initWithName:(NSString *)name
   userProfileUpdateProvider:(id<AMAUserProfileUpdateProviding>)userProfileUpdateProvider
          truncationProvider:(AMAStringAttributeTruncationProvider *)truncationProvider
    categoricalUpdateFactory:(AMACategoricalAttributeValueUpdateFactory *)categoricalUpdateFactory
{
    self = [super init];
    if (self != nil) {
        _name = [name copy];
        _userProfileUpdateProvider = userProfileUpdateProvider;
        _truncationProvider = truncationProvider;
        _categoricalUpdateFactory = categoricalUpdateFactory;
    }
    return self;
}

- (id<AMAAttributeValueUpdate>)valueUpdateWithStringValue:(NSString *)value
{
    id<AMAStringTruncating> truncator = [self.truncationProvider truncatorWithAttributeName:self.name];
    return [[AMAStringAttributeValueUpdate alloc] initWithValue:value truncator:truncator];
}

- (AMAUserProfileUpdate *)customUserProfileUpdateWithValueUpdate:(id<AMAAttributeValueUpdate>)valueUpdate
{
    return [self.userProfileUpdateProvider updateWithAttributeName:self.name
                                                              type:AMAAttributeTypeString
                                                       valueUpdate:valueUpdate];
}

- (AMAUserProfileUpdate *)withValue:(nullable NSString *)value
{
    id<AMAAttributeValueUpdate> stringValueUpdate = [self valueUpdateWithStringValue:value];
    id<AMAAttributeValueUpdate> categoricalUpdate =
        [self.categoricalUpdateFactory updateWithUnderlyingUpdate:stringValueUpdate];
    return [self customUserProfileUpdateWithValueUpdate:categoricalUpdate];
}

- (AMAUserProfileUpdate *)withValueIfUndefined:(nullable NSString *)value
{
    id<AMAAttributeValueUpdate> stringValueUpdate = [self valueUpdateWithStringValue:value];
    id<AMAAttributeValueUpdate> categoricalUpdate =
        [self.categoricalUpdateFactory updateForUndefinedWithUnderlyingUpdate:stringValueUpdate];
    return [self customUserProfileUpdateWithValueUpdate:categoricalUpdate];
}

- (AMAUserProfileUpdate *)withValueReset
{
    id<AMAAttributeValueUpdate> categoricalUpdate = [self.categoricalUpdateFactory updateWithReset];
    return [self customUserProfileUpdateWithValueUpdate:categoricalUpdate];
}

@end

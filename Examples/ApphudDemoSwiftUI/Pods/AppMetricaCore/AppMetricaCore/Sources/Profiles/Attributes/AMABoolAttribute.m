
#import "AMABoolAttribute.h"
#import "AMACategoricalAttributeValueUpdateFactory.h"
#import "AMAAttributeUpdate.h"
#import "AMABoolAttributeValueUpdate.h"
#import "AMAUserProfileUpdateProviding.h"

@interface AMABoolAttribute ()

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, strong, readonly) id<AMAUserProfileUpdateProviding> userProfileUpdateProvider;
@property (nonatomic, strong, readonly) AMACategoricalAttributeValueUpdateFactory *categoricalUpdateFactory;

@end

@implementation AMABoolAttribute

- (instancetype)initWithName:(NSString *)name
   userProfileUpdateProvider:(id<AMAUserProfileUpdateProviding>)userProfileUpdateProvider
{
    return [self initWithName:name
    userProfileUpdateProvider:userProfileUpdateProvider
     categoricalUpdateFactory:[[AMACategoricalAttributeValueUpdateFactory alloc] init]];
}

- (instancetype)initWithName:(NSString *)name
   userProfileUpdateProvider:(id<AMAUserProfileUpdateProviding>)userProfileUpdateProvider
    categoricalUpdateFactory:(AMACategoricalAttributeValueUpdateFactory *)categoricalUpdateFactory
{
    self = [super init];
    if (self != nil) {
        _name = [name copy];
        _userProfileUpdateProvider = userProfileUpdateProvider;
        _categoricalUpdateFactory = categoricalUpdateFactory;
    }
    return self;
}

- (AMAUserProfileUpdate *)customUserProfileUpdateWithValueUpdate:(id<AMAAttributeValueUpdate>)valueUpdate
{
    return [self.userProfileUpdateProvider updateWithAttributeName:self.name
                                                              type:AMAAttributeTypeBool
                                                       valueUpdate:valueUpdate];
}

- (AMAUserProfileUpdate *)withValue:(BOOL)value
{
    id<AMAAttributeValueUpdate> numberValueUpdate = [[AMABoolAttributeValueUpdate alloc] initWithValue:value];
    id<AMAAttributeValueUpdate> categoricalUpdate =
        [self.categoricalUpdateFactory updateWithUnderlyingUpdate:numberValueUpdate];
    return [self customUserProfileUpdateWithValueUpdate:categoricalUpdate];
}

- (AMAUserProfileUpdate *)withValueIfUndefined:(BOOL)value
{
    id<AMAAttributeValueUpdate> numberValueUpdate = [[AMABoolAttributeValueUpdate alloc] initWithValue:value];
    id<AMAAttributeValueUpdate> categoricalUpdate =
        [self.categoricalUpdateFactory updateForUndefinedWithUnderlyingUpdate:numberValueUpdate];
    return [self customUserProfileUpdateWithValueUpdate:categoricalUpdate];
}

- (AMAUserProfileUpdate *)withValueReset
{
    id<AMAAttributeValueUpdate> categoricalUpdate = [self.categoricalUpdateFactory updateWithReset];
    return [self customUserProfileUpdateWithValueUpdate:categoricalUpdate];
}

@end

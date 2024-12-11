
#import "AMANumberAttribute.h"
#import "AMAAttributeUpdate.h"
#import "AMANumberAttributeValueUpdate.h"
#import "AMACategoricalAttributeValueUpdateFactory.h"
#import "AMAUserProfileUpdateProviding.h"

@interface AMANumberAttribute ()

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, strong, readonly) id<AMAUserProfileUpdateProviding> userProfileUpdateProvider;
@property (nonatomic, strong, readonly) AMACategoricalAttributeValueUpdateFactory *categoricalUpdateFactory;

@end

@implementation AMANumberAttribute

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
                                                              type:AMAAttributeTypeNumber
                                                       valueUpdate:valueUpdate];
}

- (AMAUserProfileUpdate *)withValue:(double)value
{
    id<AMAAttributeValueUpdate> numberValueUpdate = [[AMANumberAttributeValueUpdate alloc] initWithValue:value];
    id<AMAAttributeValueUpdate> categoricalUpdate =
        [self.categoricalUpdateFactory updateWithUnderlyingUpdate:numberValueUpdate];
    return [self customUserProfileUpdateWithValueUpdate:categoricalUpdate];
}

- (AMAUserProfileUpdate *)withValueIfUndefined:(double)value
{
    id<AMAAttributeValueUpdate> numberValueUpdate = [[AMANumberAttributeValueUpdate alloc] initWithValue:value];
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

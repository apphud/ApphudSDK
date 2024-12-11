
#import <Foundation/Foundation.h>
#import "AMAProfileAttribute.h"

@class AMACategoricalAttributeValueUpdateFactory;
@protocol AMAUserProfileUpdateProviding;

@interface AMABoolAttribute : NSObject <AMACustomBoolAttribute, AMANotificationsEnabledAttribute>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithName:(NSString *)name
   userProfileUpdateProvider:(id<AMAUserProfileUpdateProviding>)userProfileUpdateProvider;
- (instancetype)initWithName:(NSString *)name
   userProfileUpdateProvider:(id<AMAUserProfileUpdateProviding>)userProfileUpdateProvider
    categoricalUpdateFactory:(AMACategoricalAttributeValueUpdateFactory *)categoricalUpdateFactory;

@end

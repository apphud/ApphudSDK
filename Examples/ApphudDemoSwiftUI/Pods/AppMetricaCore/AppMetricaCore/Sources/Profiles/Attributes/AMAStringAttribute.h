
#import <Foundation/Foundation.h>
#import "AMAProfileAttribute.h"

@class AMACategoricalAttributeValueUpdateFactory;
@protocol AMAUserProfileUpdateProviding;
@class AMAStringAttributeTruncationProvider;

@interface AMAStringAttribute : NSObject <AMACustomStringAttribute, AMANameAttribute>

@property (nonatomic, copy, readonly) NSString *name;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithName:(NSString *)name
   userProfileUpdateProvider:(id<AMAUserProfileUpdateProviding>)userProfileUpdateProvider
          truncationProvider:(AMAStringAttributeTruncationProvider *)truncationProvider;
- (instancetype)initWithName:(NSString *)name
   userProfileUpdateProvider:(id<AMAUserProfileUpdateProviding>)userProfileUpdateProvider
          truncationProvider:(AMAStringAttributeTruncationProvider *)truncationProvider
    categoricalUpdateFactory:(AMACategoricalAttributeValueUpdateFactory *)categoricalUpdateFactory;

@end

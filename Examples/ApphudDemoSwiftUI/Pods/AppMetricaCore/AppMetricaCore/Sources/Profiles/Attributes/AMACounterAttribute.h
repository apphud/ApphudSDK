
#import <Foundation/Foundation.h>
#import "AMAProfileAttribute.h"

@protocol AMAUserProfileUpdateProviding;

@interface AMACounterAttribute : NSObject <AMACustomCounterAttribute>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithName:(NSString *)name
   userProfileUpdateProvider:(id<AMAUserProfileUpdateProviding>)userProfileUpdateProvider;

@end

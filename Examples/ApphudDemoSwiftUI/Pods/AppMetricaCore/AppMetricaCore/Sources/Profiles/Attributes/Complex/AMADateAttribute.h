
#import <Foundation/Foundation.h>
#import "AMAProfileAttribute.h"

@class AMAStringAttribute;

@interface AMADateAttribute : NSObject <AMABirthDateAttribute>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithStringAttribute:(AMAStringAttribute *)stringAttribute;

@end

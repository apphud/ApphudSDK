
#import <Foundation/Foundation.h>
#import "AMAProfileAttribute.h"

@class AMAStringAttribute;

@interface AMAGenderAttribute : NSObject <AMAGenderAttribute>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithStringAttribute:(AMAStringAttribute *)stringAttribute;

@end

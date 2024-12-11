
#import <Foundation/Foundation.h>
#import "AMAAttributeValueUpdate.h"

@protocol AMAStringTruncating;

@interface AMAStringAttributeValueUpdate : NSObject <AMAAttributeValueUpdate>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithValue:(NSString *)value truncator:(id<AMAStringTruncating>)truncator;

@end

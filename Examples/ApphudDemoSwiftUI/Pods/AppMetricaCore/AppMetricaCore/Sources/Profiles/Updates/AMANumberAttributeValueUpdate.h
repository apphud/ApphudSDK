
#import <Foundation/Foundation.h>
#import "AMAAttributeValueUpdate.h"

@interface AMANumberAttributeValueUpdate : NSObject <AMAAttributeValueUpdate>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithValue:(double)value;

@end

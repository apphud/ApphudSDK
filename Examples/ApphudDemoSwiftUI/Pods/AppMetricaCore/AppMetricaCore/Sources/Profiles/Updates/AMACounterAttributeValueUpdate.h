
#import <Foundation/Foundation.h>
#import "AMAAttributeValueUpdate.h"

@interface AMACounterAttributeValueUpdate : NSObject <AMAAttributeValueUpdate>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithDeltaValue:(double)deltaValue;

@end

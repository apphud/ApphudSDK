
#import <Foundation/Foundation.h>
#import "AMAAttributeValueUpdate.h"

@interface AMABoolAttributeValueUpdate : NSObject <AMAAttributeValueUpdate>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithValue:(BOOL)value;

@end

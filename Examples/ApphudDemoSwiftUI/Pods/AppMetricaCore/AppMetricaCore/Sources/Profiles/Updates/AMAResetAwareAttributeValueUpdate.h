
#import <Foundation/Foundation.h>
#import "AMAAttributeValueUpdate.h"

@interface AMAResetAwareAttributeValueUpdate : NSObject <AMAAttributeValueUpdate>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithIsReset:(BOOL)isReset
          underlyingValueUpdate:(id<AMAAttributeValueUpdate>)underlyingValueUpdate;

@end


#import <Foundation/Foundation.h>
#import "AMAAttributeValueUpdate.h"

@interface AMAUndefinedAwareAttributeValueUpdate : NSObject <AMAAttributeValueUpdate>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithIsUndefined:(BOOL)isUndefined
              underlyingValueUpdate:(id<AMAAttributeValueUpdate>)underlyingValueUpdate;

@end

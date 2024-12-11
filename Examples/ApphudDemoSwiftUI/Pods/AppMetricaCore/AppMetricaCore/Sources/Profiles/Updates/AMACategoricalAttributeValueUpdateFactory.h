
#import <Foundation/Foundation.h>

@protocol AMAAttributeValueUpdate;

@interface AMACategoricalAttributeValueUpdateFactory : NSObject

- (id<AMAAttributeValueUpdate>)updateWithUnderlyingUpdate:(id<AMAAttributeValueUpdate>)underlyingUpdate;
- (id<AMAAttributeValueUpdate>)updateForUndefinedWithUnderlyingUpdate:(id<AMAAttributeValueUpdate>)underlyingUpdate;
- (id<AMAAttributeValueUpdate>)updateWithReset;

@end

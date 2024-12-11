
#import <Foundation/Foundation.h>

@class AMAAttributeValue;

@protocol AMAAttributeValueUpdate <NSObject>

- (void)applyToValue:(AMAAttributeValue *)value;

@end

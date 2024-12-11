
#import <Foundation/Foundation.h>

@class AMALightECommerceEvent;
@class AMAECommerce;

@interface AMALightECommerceEventConverter : NSObject

- (AMALightECommerceEvent *)eventFromModel:(AMAECommerce *)event;
- (AMALightECommerceEvent *)eventFromSerializedValue:(id)value;

@end

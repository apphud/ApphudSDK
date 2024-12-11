
#import <Foundation/Foundation.h>

@class AMALightRevenueEvent;
@class AMALightECommerceEvent;

@protocol AMAAttributionModel <NSObject>

- (NSNumber *)checkAttributionForClientEvent:(NSString *)name;
- (NSNumber *)checkAttributionForECommerceEvent:(AMALightECommerceEvent *)event;
- (NSNumber *)checkAttributionForRevenueEvent:(AMALightRevenueEvent *)event;
- (NSNumber *)checkInitialAttribution;

@end

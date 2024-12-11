
#import <Foundation/Foundation.h>
#import "AMAECommerce+Internal.h"
#import "AMAAttributionModel.h"

@class AMARevenueAttributionModelConfiguration;
@class AMAECommerceAmount;
@class AMAEventSumBoundBasedModelHelper;
@class AMALightECommerceEvent;
@class AMALightRevenueEvent;

@interface AMARevenueAttributionModel : NSObject <AMAAttributionModel>

- (instancetype)initWithConfig:(AMARevenueAttributionModelConfiguration *)config;
- (instancetype)initWithConfig:(AMARevenueAttributionModelConfiguration *)config
 eventSumBoundBasedModelHelper:(AMAEventSumBoundBasedModelHelper *)eventSumBoundBasedModelHelper;

@end

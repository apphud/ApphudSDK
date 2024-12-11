
#import <Foundation/Foundation.h>
#import "AMAEventTypes.h"
#import "AMAECommerce+Internal.h"
#import "AMAAttributionModel.h"

@class AMAConversionAttributionModelConfiguration;
@class AMAEventCountByKeyHelper;
@class AMALightECommerceEvent;
@class AMALightRevenueEvent;

@interface AMAConversionAttributionModel : NSObject <AMAAttributionModel>

- (instancetype)initWithConfig:(AMAConversionAttributionModelConfiguration *)config;
- (instancetype)initWithConfig:(AMAConversionAttributionModelConfiguration *)config
         eventCountByKeyHelper:(AMAEventCountByKeyHelper *)eventCountByKeyHelper;

@end

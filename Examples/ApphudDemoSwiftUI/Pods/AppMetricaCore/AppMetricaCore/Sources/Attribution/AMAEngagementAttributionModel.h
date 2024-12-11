
#import <Foundation/Foundation.h>
#import "AMAEventTypes.h"
#import "AMAECommerce+Internal.h"
#import "AMAAttributionModel.h"

@class AMAEngagementAttributionModelConfiguration;
@class AMABoundMappingChecker;
@class AMAEventCountByKeyHelper;
@class AMALightECommerceEvent;
@class AMALightRevenueEvent;

@interface AMAEngagementAttributionModel : NSObject <AMAAttributionModel>

@property (nonatomic, assign, readonly) AMAEventType type;

- (instancetype)initWithConfig:(AMAEngagementAttributionModelConfiguration *)config;
- (instancetype)initWithConfig:(AMAEngagementAttributionModelConfiguration *)config
         eventCountByKeyHelper:(AMAEventCountByKeyHelper *)eventCountByKeyHelper
           boundMappingChecker:(AMABoundMappingChecker *)boundMappingChecker;

@end

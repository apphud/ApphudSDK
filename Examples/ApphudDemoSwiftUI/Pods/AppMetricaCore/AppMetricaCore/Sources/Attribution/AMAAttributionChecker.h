
#import <Foundation/Foundation.h>

@class AMAAttributionModelConfiguration;
@class AMARevenueInfoModel;
@class AMAECommerce;
@class AMAEvent;
@class AMARevenueDeduplicator;
@protocol AMAAttributionModel;
@class AMALightECommerceEventConverter;
@class AMALightRevenueEventConverter;
@class AMAReporter;

@interface AMAAttributionChecker : NSObject

- (instancetype)initWithConfig:(AMAAttributionModelConfiguration *)config
                      reporter:(AMAReporter *)reporter;
- (instancetype)initWithConfig:(AMAAttributionModelConfiguration *)config
                      reporter:(AMAReporter *)reporter
              attributionModel:(id<AMAAttributionModel>)model
           revenueDeduplicator:(AMARevenueDeduplicator *)revenueDeduplicator
  lightECommerceEventConverter:(AMALightECommerceEventConverter *)lightECommerceEventConverter
    lightRevenueEventConverter:(AMALightRevenueEventConverter *)lightRevenueEventConverter;

- (void)checkClientEventAttribution:(NSString *)eventName;
- (void)checkRevenueEventAttribution:(AMARevenueInfoModel *)revenue;
- (void)checkECommerceEventAttribution:(AMAECommerce *)eCommerce;
- (void)checkSerializedEventAttribution:(AMAEvent *)serializedEvent;
- (void)checkInitialAttribution;

@end

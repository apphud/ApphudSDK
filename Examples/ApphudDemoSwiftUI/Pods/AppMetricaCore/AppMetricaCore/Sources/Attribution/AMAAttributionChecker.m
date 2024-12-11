
#import "AMAAttributionChecker.h"
#import "AMAAttributionModelConfiguration.h"
#import "AMAEvent.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaPersistentConfiguration.h"
#import "AMASKAdNetworkRequestor.h"
#import "AMAConversionAttributionModel.h"
#import "AMAEngagementAttributionModel.h"
#import "AMARevenueAttributionModel.h"
#import "AMARevenueInfoModel.h"
#import "AMARevenueDeduplicator.h"
#import "AMAReporter.h"
#import "AMALightECommerceEventConverter.h"
#import "AMALightRevenueEventConverter.h"
#import "AMALightRevenueEvent.h"

@interface AMAAttributionChecker ()

@property (nonatomic, strong, readonly) AMAAttributionModelConfiguration *config;
@property (nonatomic, strong, readonly) AMAReporter *reporter;
@property (nonatomic, strong, readonly) id<AMAAttributionModel> attributionModel;
@property (nonatomic, strong, readonly) AMARevenueDeduplicator *revenueDeduplicator;
@property (nonatomic, strong, readonly) AMALightECommerceEventConverter *lightECommerceEventConverter;
@property (nonatomic, strong, readonly) AMALightRevenueEventConverter *lightRevenueEventConverter;

@end

typedef NS_ENUM(NSInteger, AMAConvertingErrorCode) {
    AMAProtobufDeserializationFailed,
};

@implementation AMAAttributionChecker

- (instancetype)initWithConfig:(AMAAttributionModelConfiguration *)config
                      reporter:(AMAReporter *)reporter
{
    id<AMAAttributionModel> model = nil;
    switch (config.type) {
        case AMAAttributionModelTypeConversion:
            model = [[AMAConversionAttributionModel alloc] initWithConfig:config.conversion];
            break;
        case AMAAttributionModelTypeEngagement:
            model = [[AMAEngagementAttributionModel alloc] initWithConfig:config.engagement];
            break;
        case AMAAttributionModelTypeRevenue:
            model = [[AMARevenueAttributionModel alloc] initWithConfig:config.revenue];
            break;
        default:
            model = nil;
            break;
    }
    return [self initWithConfig:config
                       reporter:reporter
               attributionModel:model
            revenueDeduplicator:[[AMARevenueDeduplicator alloc] initWithConfig:config]
   lightECommerceEventConverter:[[AMALightECommerceEventConverter alloc] init]
     lightRevenueEventConverter:[[AMALightRevenueEventConverter alloc] init]];
}

- (instancetype)initWithConfig:(AMAAttributionModelConfiguration *)config
                      reporter:(AMAReporter *)reporter
              attributionModel:(id<AMAAttributionModel>)model
           revenueDeduplicator:(AMARevenueDeduplicator *)revenueDeduplicator
  lightECommerceEventConverter:(AMALightECommerceEventConverter *)lightECommerceEventConverter
    lightRevenueEventConverter:(AMALightRevenueEventConverter *)lightRevenueEventConverter
{
    self = [super init];
    if (self != nil) {
        _config = config;
        _reporter = reporter;
        _attributionModel = model;
        _revenueDeduplicator = revenueDeduplicator;
        _lightECommerceEventConverter = lightECommerceEventConverter;
        _lightRevenueEventConverter = lightRevenueEventConverter;
    }
    return self;
}

#pragma mark - Public -

- (void)checkClientEventAttribution:(NSString *)eventName
{
    AMALogInfo(@"Event name: %@, config type: %lu", eventName, (unsigned long)self.config.type);
    [self maybeUpdateConversionValue:[self.attributionModel checkAttributionForClientEvent:eventName]];
}

- (void)checkRevenueEventAttribution:(AMARevenueInfoModel *)revenue
{
    AMALogInfo(@"Revenue: %@, config type: %tu", revenue, self.config.type);
    AMALightRevenueEvent *event = [self.lightRevenueEventConverter eventFromModel:revenue];
    if (event.isRestore) {
        AMALogInfo(@"Ignoring restore");
        return;
    }
    if ([self.revenueDeduplicator checkForID:event.transactionID] == NO) {
        AMALogInfo(@"Ignoring duplicate revenue");
        return;
    }
    [self maybeUpdateConversionValue:[self.attributionModel checkAttributionForRevenueEvent:event]];
}

- (void)checkECommerceEventAttribution:(AMAECommerce *)eCommerce
{
    AMALogInfo(@"ECommerce event type: %tu, config type: %tu", eCommerce.eventType, self.config.type);
    AMALightECommerceEvent *lightEvent = [self.lightECommerceEventConverter eventFromModel:eCommerce];
    [self maybeUpdateConversionValue:[self.attributionModel checkAttributionForECommerceEvent:lightEvent]];
}

- (void)checkSerializedEventAttribution:(AMAEvent *)serializedEvent
{
    AMALogInfo(@"Event type: %tu, config type: %tu", serializedEvent.type, self.config.type);
    switch (serializedEvent.type) {
        case AMAEventTypeClient: {
            [self maybeUpdateConversionValue:[self.attributionModel checkAttributionForClientEvent:serializedEvent.name]];
            break;
        }
        case AMAEventTypeECommerce: {
            AMALightECommerceEvent *event = [self.lightECommerceEventConverter eventFromSerializedValue:serializedEvent.value];
            [self maybeUpdateConversionValue:[self.attributionModel checkAttributionForECommerceEvent:event]];
            break;
        }
        case AMAEventTypeRevenue: {
            AMALightRevenueEvent *event = [self.lightRevenueEventConverter eventFromSerializedValue:serializedEvent.value];
            if (event.isRestore) {
                AMALogInfo(@"Ignoring restore");
                break;
            }
            if ([self.revenueDeduplicator checkForID:event.transactionID] == NO) {
                AMALogInfo(@"Ignoring restore");
                break;
            }
            [self maybeUpdateConversionValue:[self.attributionModel checkAttributionForRevenueEvent:event]];
            break;
        }
        default: break;
    }
}

- (void)checkInitialAttribution
{
    [self maybeUpdateConversionValue:[self.attributionModel checkInitialAttribution]];
}

#pragma mark - Private -

- (void)maybeUpdateConversionValue:(NSNumber *)newValue
{
    NSNumber *oldValue = [AMAMetricaConfiguration sharedInstance].persistent.conversionValue;
    AMALogInfo(@"New value: %@, old value: %@", newValue, oldValue);
    if (newValue != nil && (oldValue == nil || newValue.integerValue != oldValue.integerValue)) {
        [AMAMetricaConfiguration sharedInstance].persistent.conversionValue = newValue;
        BOOL updated = [[AMASKAdNetworkRequestor sharedInstance] updateConversionValue:newValue.integerValue];
        if (updated) {
            [self reportUpdateConversionValueEventWithOldValue:oldValue newValue:newValue];
        }
    }
}

- (void)reportUpdateConversionValueEventWithOldValue:(NSNumber *)oldValue newValue:(NSNumber *)newValue
{
    NSMutableDictionary *value = [NSMutableDictionary dictionary];
    value[@"old_value"] = oldValue;
    value[@"new_value"] = newValue;
    [self.reporter reportAttributionEventWithName:@"conversion_value_update" value:[value copy]];
}

@end

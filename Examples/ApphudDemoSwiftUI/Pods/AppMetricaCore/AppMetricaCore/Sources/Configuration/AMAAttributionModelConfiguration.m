
#import "AMAAttributionModelConfiguration.h"
#import "AMAStorageKeys.h"
#import "AMAConversionAttributionModelConfiguration.h"
#import "AMARevenueAttributionModelConfiguration.h"
#import "AMAEngagementAttributionModelConfiguration.h"

@implementation AMAAttributionModelConfiguration

@synthesize maxSavedRevenueIDs = _maxSavedRevenueIDs;

static NSString *const kAMAKeyStopSendingTimeSeconds = @"stop.sending.time.seconds";
static NSString *const kAMAKeyMaxSavedRevenueIDs = @"max.saved.revenue.ids";
static NSString *const kAMAKeyModelType = @"model.type";
static NSString *const kAMAKeyConversion = @"conversion";
static NSString *const kAMAKeyRevenue = @"revenue";
static NSString *const kAMAKeyEngagement = @"engagement";

static NSUInteger const kAMADefaultMaxSavedRevenueIDs = 50;

- (instancetype)initWithType:(AMAAttributionModelType)type
          maxSavedRevenueIDs:(NSNumber *)maxSavedRevenueIDs
      stopSendingTimeSeconds:(NSNumber *)stopSendingTimeSeconds
                  conversion:(AMAConversionAttributionModelConfiguration *)conversion
                     revenue:(AMARevenueAttributionModelConfiguration *)revenue
                  engagement:(AMAEngagementAttributionModelConfiguration *)engagement
{
    self = [super init];
    if (self != nil) {
        _type = type;
        _maxSavedRevenueIDs = maxSavedRevenueIDs;
        _stopSendingTimeSeconds = stopSendingTimeSeconds;
        _conversion = conversion;
        _revenue = revenue;
        _engagement = engagement;
    }
    return self;
}

- (instancetype)initWithJSON:(NSDictionary *)json
{
    if (json == nil) {
        return nil;
    }
    return [self initWithType:(AMAAttributionModelType)(((NSNumber *)json[kAMAKeyModelType]).intValue)
           maxSavedRevenueIDs:json[kAMAKeyMaxSavedRevenueIDs]
       stopSendingTimeSeconds:json[kAMAKeyStopSendingTimeSeconds]
                   conversion:[[AMAConversionAttributionModelConfiguration alloc] initWithJSON:json[kAMAKeyConversion]]
                      revenue:[[AMARevenueAttributionModelConfiguration alloc] initWithJSON:json[kAMAKeyRevenue]]
                   engagement:[[AMAEngagementAttributionModelConfiguration alloc] initWithJSON:json[kAMAKeyEngagement]]];
}

- (NSNumber *)maxSavedRevenueIDs
{
    return _maxSavedRevenueIDs == nil ? @(kAMADefaultMaxSavedRevenueIDs) : _maxSavedRevenueIDs;
}

- (NSDictionary *)JSON
{
    NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
    json[kAMAKeyModelType] = @((int) self.type);
    json[kAMAKeyMaxSavedRevenueIDs] = self.maxSavedRevenueIDs;
    json[kAMAKeyStopSendingTimeSeconds] = self.stopSendingTimeSeconds;
    json[kAMAKeyConversion] = [self.conversion JSON];
    json[kAMAKeyRevenue] = [self.revenue JSON];
    json[kAMAKeyEngagement] = [self.engagement JSON];
    return [json copy];
}

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.type=%lu", (unsigned long)self.type];
    [description appendFormat:@", self.maxSavedRevenueIDs=%@", self.maxSavedRevenueIDs];
    [description appendFormat:@", self.stopSendingTimeSeconds=%@", self.stopSendingTimeSeconds];
    [description appendFormat:@", self.conversion=%@", self.conversion];
    [description appendFormat:@", self.revenue=%@", self.revenue];
    [description appendFormat:@", self.engagement=%@", self.engagement];
    [description appendString:@">"];
    return description;
}


@end

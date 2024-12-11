
#import "AMACore.h"
#import <CoreLocation/CoreLocation.h>
#import "AMALocationCollectingConfiguration.h"
#import "AMAMetricaConfiguration.h"
#import "AMAStartupParametersConfiguration.h"

@interface AMALocationCollectingConfiguration ()

@property (nonatomic, strong, readonly) AMAMetricaConfiguration *metricaConfiguration;

@end

@implementation AMALocationCollectingConfiguration

- (instancetype)init
{
    return [self initWithMetricaConfiguration:[AMAMetricaConfiguration sharedInstance]];
}

- (instancetype)initWithMetricaConfiguration:(AMAMetricaConfiguration *)metricaConfiguration
{
    self = [super init];
    if (self != nil) {
        _metricaConfiguration = metricaConfiguration;
    }
    return self;
}

- (BOOL)collectingEnabled
{
    return self.metricaConfiguration.startup.locationCollectingEnabled;
}

- (BOOL)visitsCollectingEnabled
{
    return self.metricaConfiguration.startup.locationVisitsCollectingEnabled;
}

- (NSArray *)hosts
{
    return self.metricaConfiguration.startup.locationHosts;
}

- (NSTimeInterval)minUpdateInterval
{
    return [AMATimeUtilities intervalWithNumber:self.metricaConfiguration.startup.locationMinUpdateInterval
                                defaultInterval:5.0];
}

- (double)minUpdateDistance
{
    return [AMANumberUtilities doubleWithNumber:self.metricaConfiguration.startup.locationMinUpdateDistance
                                   defaultValue:10.0];
}

- (NSUInteger)recordsCountToForceFlush
{
    return [AMANumberUtilities
                unsignedIntegerForNumber:self.metricaConfiguration.startup.locationRecordsCountToForceFlush
                defaultValue:10];
}

- (NSUInteger)maxRecordsCountInBatch
{
    return [AMANumberUtilities
                unsignedIntegerForNumber:self.metricaConfiguration.startup.locationMaxRecordsCountInBatch
                defaultValue:100];
}

- (NSTimeInterval)maxAgeToForceFlush
{
    return [AMATimeUtilities intervalWithNumber:self.metricaConfiguration.startup.locationMaxAgeToForceFlush
                                defaultInterval:60.0];
}

- (NSUInteger)maxRecordsToStoreLocally
{
    return [AMANumberUtilities
                unsignedIntegerForNumber:self.metricaConfiguration.startup.locationMaxRecordsToStoreLocally
                defaultValue:5000];
}

- (double)defaultDesiredAccuracy
{
    return [AMANumberUtilities doubleWithNumber:self.metricaConfiguration.startup.locationDefaultDesiredAccuracy
                                   defaultValue:kCLLocationAccuracyHundredMeters];
}

- (double)defaultDistanceFilter
{
    return [AMANumberUtilities doubleWithNumber:self.metricaConfiguration.startup.locationDefaultDistanceFilter
                                   defaultValue:350.0];
}

- (double)accurateDesiredAccuracy
{
    return [AMANumberUtilities doubleWithNumber:self.metricaConfiguration.startup.locationAccurateDesiredAccuracy
                                   defaultValue:kCLLocationAccuracyNearestTenMeters];
}

- (double)accurateDistanceFilter
{
    return [AMANumberUtilities doubleWithNumber:self.metricaConfiguration.startup.locationAccurateDistanceFilter
                                   defaultValue:10.0];
}

- (BOOL)pausesLocationUpdatesAutomatically
{
    return [AMANumberUtilities
                boolForNumber:self.metricaConfiguration.startup.locationPausesLocationUpdatesAutomatically
                defaultValue:YES];
}

@end

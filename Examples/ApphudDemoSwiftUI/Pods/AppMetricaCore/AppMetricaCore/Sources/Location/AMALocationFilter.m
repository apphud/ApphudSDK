
#import "AMALocationFilter.h"
#import "AMALocationCollectingConfiguration.h"
#import <CoreLocation/CoreLocation.h>

@interface AMALocationFilter ()

@property (nonatomic, strong, readonly) AMALocationCollectingConfiguration *configuration;

@property (nonatomic, strong) CLLocation *lastLocation;
@property (nonatomic, strong) NSDate *lastDate;

@end

@implementation AMALocationFilter

- (instancetype)initWithConfiguration:(AMALocationCollectingConfiguration *)configuration
{
    self = [super init];
    if (self != nil) {
        _configuration = configuration;
    }
    return self;
}

- (BOOL)shouldAddLocation:(CLLocation *)location atDate:(NSDate *)date
{
    BOOL shouldAdd = NO;
    if (self.lastLocation != nil && self.lastDate != nil) {
        shouldAdd = shouldAdd || ([date timeIntervalSinceDate:self.lastDate] >= self.configuration.minUpdateInterval);
        shouldAdd = shouldAdd
            || ([location distanceFromLocation:self.lastLocation] >= self.configuration.minUpdateDistance);
    }
    else {
        shouldAdd = YES;
    }
    return shouldAdd;
}

- (void)updateLastLocation:(CLLocation *)location atDate:(NSDate *)date
{
    self.lastLocation = location;
    self.lastDate = date;
}

@end

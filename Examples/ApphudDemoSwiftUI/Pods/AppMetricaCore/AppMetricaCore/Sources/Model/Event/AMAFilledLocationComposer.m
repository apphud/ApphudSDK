
#import "AMAFilledLocationComposer.h"
#import "AMALocationManager.h"

@interface AMAFilledLocationComposer()

@property(nonatomic, strong, readonly) AMALocationManager *locationManager;

@end

@implementation AMAFilledLocationComposer

- (instancetype)initWithLocationManager:(AMALocationManager *)manager
{
    self = [super init];
    if (self != nil) {
        _locationManager = manager;
    }
    return self;
}

- (CLLocation *)compose
{
    return [self.locationManager currentLocation];
}

@end


#import "AMAFilledLocationEnabledComposer.h"
#import "AMALocationManager.h"

@interface AMAFilledLocationEnabledComposer()

@property(nonatomic, strong, readonly) AMALocationManager *locationManager;

@end

@implementation AMAFilledLocationEnabledComposer

- (instancetype)initWithLocationManager:(AMALocationManager *)manager
{
    self = [super init];
    if (self != nil) {
        _locationManager = manager;
    }
    return self;
}

- (AMAOptionalBool)compose
{
    return [AMALocationManager sharedManager].trackLocationEnabled ? AMAOptionalBoolTrue : AMAOptionalBoolFalse;
}

@end

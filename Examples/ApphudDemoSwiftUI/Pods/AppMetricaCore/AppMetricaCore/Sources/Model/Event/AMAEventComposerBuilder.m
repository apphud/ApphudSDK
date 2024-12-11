
#import "AMAEventComposerBuilder.h"
#import "AMAEventComposer.h"
#import "AMAFilledLocationComposer.h"
#import "AMAFilledAppEnvironmentComposer.h"
#import "AMADummyEventEnvironmentComposer.h"
#import "AMAReporterStateStorage.h"
#import "AMAFilledProfileIdComposer.h"
#import "AMALocationEnabledComposer.h"
#import "AMAFilledLocationEnabledComposer.h"
#import "AMALocationManager.h"
#import "AMAOpenIDComposer.h"
#import "AMAFilledOpenIDComposer.h"
#import "AMAFilledExtrasComposer.h"

@interface AMAEventComposerBuilder ()

@property(nonatomic, strong, readwrite) id <AMAProfileIdComposer> profileIdComposer;
@property(nonatomic, strong, readwrite) id <AMALocationComposer> locationComposer;
@property(nonatomic, strong, readwrite) id <AMALocationEnabledComposer> locationEnabledComposer;
@property(nonatomic, strong, readwrite) id <AMAAppEnvironmentComposer> appEnvironmentComposer;
@property(nonatomic, strong, readwrite) id <AMAEventEnvironmentComposer> eventEnvironmentComposer;
@property(nonatomic, strong, readwrite) id <AMAOpenIDComposer> openIDComposer;
@property(nonatomic, strong, readwrite) id <AMAExtrasComposer> extrasComposer;

@end

@implementation AMAEventComposerBuilder

- (instancetype)initWithStorage:(AMAReporterStateStorage *)storage
{
    self = [super init];
    if (self != nil) {
        _profileIdComposer = [[AMAFilledProfileIdComposer alloc] initWithStorage:storage];
        _openIDComposer = [[AMAFilledOpenIDComposer alloc] initWithStorage:storage];
        AMALocationManager *locationManager = [AMALocationManager sharedManager];
        _locationComposer = [[AMAFilledLocationComposer alloc] initWithLocationManager:locationManager];
        _locationEnabledComposer = [[AMAFilledLocationEnabledComposer alloc] initWithLocationManager:locationManager];
        _appEnvironmentComposer = [[AMAFilledAppEnvironmentComposer alloc] initWithStorage:storage];
        _eventEnvironmentComposer = [AMADummyEventEnvironmentComposer new];
        _extrasComposer = [[AMAFilledExtrasComposer alloc] initWithStorage:storage];
    }
    return self;
}

- (void)addProfileIdComposer:(id<AMAProfileIdComposer>)profileIdComposer
{
    self.profileIdComposer = profileIdComposer;
}

- (void)addLocationComposer:(id<AMALocationComposer>)locationComposer
{
    self.locationComposer = locationComposer;
}

- (void)addLocationEnabledComposer:(id<AMALocationEnabledComposer>)locationEnabledComposer
{
    self.locationEnabledComposer = locationEnabledComposer;
}

- (void)addAppEnvironmentComposer:(id<AMAAppEnvironmentComposer>)appEnvironmentComposer
{
    self.appEnvironmentComposer = appEnvironmentComposer;
}

- (void)addEventEnvironmentComposer:(id<AMAEventEnvironmentComposer>)eventEnvironmentComposer
{
    self.eventEnvironmentComposer = eventEnvironmentComposer;
}

- (void)addOpenIDComposer:(id<AMAOpenIDComposer>)openIDComposer
{
    self.openIDComposer = openIDComposer;
}

- (void)addExtrasComposer:(id<AMAExtrasComposer>)extrasComposer
{
    self.extrasComposer = extrasComposer;
}

- (AMAEventComposer *)build
{
    return [[AMAEventComposer alloc] initWithBuilder:self];
}

+ (instancetype)defaultBuilderWithStorage:(AMAReporterStateStorage *)storage
{
    return [[AMAEventComposerBuilder alloc] initWithStorage:storage];
}

@end

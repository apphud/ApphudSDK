
#import "AMAEventComposer.h"
#import "AMAEventComposerBuilder.h"
#import "AMAEvent.h"
#import "AMALocationComposer.h"
#import "AMALocationEnabledComposer.h"
#import "AMAAppEnvironmentComposer.h"
#import "AMAEventEnvironmentComposer.h"
#import "AMAProfileIdComposer.h"
#import "AMAOpenIDComposer.h"
#import "AMAExtrasComposer.h"

@interface AMAEventComposer ()

@property(nonatomic, strong, readonly) id<AMAProfileIdComposer> profileIdComposer;
@property(nonatomic, strong, readonly) id<AMALocationComposer> locationComposer;
@property(nonatomic, strong, readonly) id<AMALocationEnabledComposer> locationEnabledComposer;
@property(nonatomic, strong, readonly) id<AMAAppEnvironmentComposer> appEnvironmentComposer;
@property(nonatomic, strong, readonly) id<AMAEventEnvironmentComposer> eventEnvironmentComposer;
@property(nonatomic, strong, readonly) id<AMAOpenIDComposer> openIDComposer;
@property(nonatomic, strong, readonly) id<AMAExtrasComposer> extrasComposer;

@end

@implementation AMAEventComposer

- (instancetype)initWithBuilder:(AMAEventComposerBuilder *)builder
{
    self = [super init];
    if (self) {
        _profileIdComposer = builder.profileIdComposer;
        _locationComposer = builder.locationComposer;
        _locationEnabledComposer = builder.locationEnabledComposer;
        _appEnvironmentComposer = builder.appEnvironmentComposer;
        _eventEnvironmentComposer = builder.eventEnvironmentComposer;
        _openIDComposer = builder.openIDComposer;
        _extrasComposer = builder.extrasComposer;
    }
    return self;
}

- (void)compose:(AMAEvent *)event
{
    event.profileID = [self.profileIdComposer compose];
    event.openID = @([self.openIDComposer compose]);
    event.location = [self.locationComposer compose];
    event.locationEnabled = [self.locationEnabledComposer compose];
    event.appEnvironment = [self.appEnvironmentComposer compose];
    event.eventEnvironment = [self.eventEnvironmentComposer compose];
    event.extras = [self.extrasComposer compose];
}

@end


#import <AppMetricaAdSupport/AppMetricaAdSupport.h>
#import <AppMetricaCore/AppMetricaCore.h>
#import "AMAATTStatusProvider.h"
#import "AMAIDFAProvider.h"

@interface AMAAdController ()

@property (nonatomic, strong) AMAIDFAProvider *idfaProvider;
@property (nonatomic, strong) AMAATTStatusProvider *attStatusProvider;

@end

@implementation AMAAdController

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _idfaProvider = [[AMAIDFAProvider alloc] init];
        _attStatusProvider = [[AMAATTStatusProvider alloc] init];
    }
    return self;
}

+ (void)load
{
    [AMAAppMetrica registerAdProvider:[[[self class] alloc] init]];
}

- (NSUUID *)advertisingIdentifier
{
    return [self.idfaProvider advertisingIdentifier];
}

- (BOOL)isAdvertisingTrackingEnabled
{
    return [self.attStatusProvider isAdvertisingTrackingEnabled];
}

- (AMATrackingManagerAuthorizationStatus)ATTStatus API_AVAILABLE(ios(14.0), tvos(14.0))
{
    return [self.attStatusProvider ATTStatus];
}

@end

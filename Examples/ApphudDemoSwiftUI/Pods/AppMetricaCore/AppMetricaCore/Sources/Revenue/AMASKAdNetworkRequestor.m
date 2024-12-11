
#import <StoreKit/StoreKit.h>
#import "AMACore.h"
#import "AMASKAdNetworkRequestor.h"
#import "AMAMetricaDynamicFrameworks.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaPersistentConfiguration.h"

@interface AMASKAdNetworkRequestor ()

@property (nonatomic, strong, readonly) AMAFramework *storeKit;
@property (nonatomic, strong, readonly) id<AMADateProviding> dateProvider;

@end

static NSString *const kAMASKAdNetworkClass = @"SKAdNetwork";

@implementation AMASKAdNetworkRequestor

+ (instancetype)sharedInstance
{
    static dispatch_once_t pred;
    static AMASKAdNetworkRequestor *shared = nil;
    dispatch_once(&pred, ^{
        shared = (AMASKAdNetworkRequestor *)[[[self class] alloc] init];
    });
    return shared;
}

- (instancetype)init
{
    return [self initWithDateProvider:[[AMADateProvider alloc] init]];
}

- (instancetype)initWithDateProvider:(id<AMADateProviding>)dateProvider
{
    self = [super init];
    if (self != nil) {
        _storeKit = AMAMetricaDynamicFrameworks.storeKit;
        _dateProvider = dateProvider;
    }
    return self;
}

#pragma mark - Public -

#pragma clang diagnostic push
#pragma ide diagnostic ignored "UnavailableInDeploymentTarget"
- (void)registerForAdNetworkAttribution
{
    if (@available(iOS 11.3, *)) {
        if (self.isFirstExecution) {
            Class adNetwork = [self.storeKit classFromString:kAMASKAdNetworkClass];
            if (adNetwork != Nil) {
                [adNetwork registerAppForAdNetworkAttribution];
                [AMAMetricaConfiguration sharedInstance].persistent.registerForAttributionTime = self.dateProvider.currentDate;
                AMALogNotify(@"Registered for SKAdNetwork attribution");
            }
            else {
                AMALogNotify(@"SKAdNetwork is unavailable");
            }
        }
        else {
            AMALogNotify(@"Not a first execution of an app. Skipping registering");
        }
    }
    else {
        AMALogNotify(@"SKAdNetwork attribution is unavailable. OS version is lower than iOS 11.3");
    }
}

- (BOOL)updateConversionValue:(NSInteger)value
{
    if (@available(iOS 14.0, *)) {
        Class adNetwork = [self.storeKit classFromString:kAMASKAdNetworkClass];
        if (adNetwork != Nil) {
            AMALogInfo(@"Updating conversion value: %ld", (long) value);
            [adNetwork updateConversionValue:value];
            return YES;
        }
    }
    return NO;
}
#pragma clang diagnostic pop

#pragma mark - Private -

- (BOOL)isFirstExecution
{
    return [AMAMetricaConfiguration sharedInstance].persistent.hadFirstStartup == NO;
}

@end

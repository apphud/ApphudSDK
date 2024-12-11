
#import "AMACore.h"
#import "AMAErrorLogger.h"
#import "AMAErrorsFactory.h"

static NSString *const kAMAInvalidApiKeyMsgFormat = @"Invalid apiKey \"%@\". ApiKey must be a hexadecimal string in format xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx. ApiKey can be requested or checked at https://appmetrica.io";
static NSString *const kAMAMetricaNotStartedMsg = @"activateWithApiKey: or activateWithConfiguration: aren't called";
static NSString *const kAMAMetricaAlreadyStartedMsg = @"Failed to activate AppMetrica; AppMetrica has already been started";
static NSString *const kAMAMetricaActivationWithPresentedKeyMsg = @"Failed to activate AppMetrica with provided apiKey. ApiKey has already been used by another reporter";
static NSString *const kAMAMetricaActivationWithSessionsAutoTrackingMsg = @"Failed to pause/resume session because AppMetrica has been activated with sessionsAutoTracking enabled";

static NSString *const kAMAInvalidParameterMessageForAppVersionMsg = @"appVersion can't be nil or an empty string";
static NSString *const kAMAInvalidParameterMessageForAppBuildNumberMsg = @"appBuildNumber must be a string containing a positive number";

@implementation AMAErrorLogger

+ (void)logAppMetricaNotStartedErrorWithOnFailure:(void (^)(NSError *error))failureCallback
{
    [AMAFailureDispatcher dispatchError:[AMAErrorsFactory appMetricaNotStartedError] withBlock:failureCallback];
    AMALogError(kAMAMetricaNotStartedMsg);
}

+ (void)logInvalidApiKeyError:(NSString *)apiKey
{
    AMALogError(kAMAInvalidApiKeyMsgFormat, apiKey);
}

+ (void)logMetricaAlreadyStartedError
{
    AMALogError(kAMAMetricaAlreadyStartedMsg);
}

+ (void)logMetricaActivationWithAlreadyPresentedKeyError
{
    AMALogError(kAMAMetricaActivationWithPresentedKeyMsg);
}

+ (void)logMetricaActivationWithAutomaticSessionsTracking
{
    AMALogError(kAMAMetricaActivationWithSessionsAutoTrackingMsg);
}

+ (void)logInvalidCustomAppVersionError
{
    AMALogError(kAMAInvalidParameterMessageForAppVersionMsg);
}

+ (void)logInvalidCustomAppBuildNumberError
{
    AMALogError(kAMAInvalidParameterMessageForAppBuildNumberMsg);
}

@end

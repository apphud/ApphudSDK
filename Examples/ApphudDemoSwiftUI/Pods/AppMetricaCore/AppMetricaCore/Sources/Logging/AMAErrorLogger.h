
#import <Foundation/Foundation.h>

@interface AMAErrorLogger : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (void)logAppMetricaNotStartedErrorWithOnFailure:(void (^)(NSError *error))failureCallback;
+ (void)logInvalidApiKeyError:(NSString *)apiKey;
+ (void)logMetricaAlreadyStartedError;
+ (void)logMetricaActivationWithAlreadyPresentedKeyError;
+ (void)logMetricaActivationWithAutomaticSessionsTracking;

+ (void)logInvalidCustomAppVersionError;
+ (void)logInvalidCustomAppBuildNumberError;

@end

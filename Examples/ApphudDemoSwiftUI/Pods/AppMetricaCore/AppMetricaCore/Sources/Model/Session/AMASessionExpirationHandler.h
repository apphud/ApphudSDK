
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AMAMetricaConfiguration;
@class AMASession;

typedef NS_ENUM(NSUInteger, AMASessionExpirationType) {
    AMASessionExpirationTypeNone,
    AMASessionExpirationTypeTimeout,
    AMASessionExpirationTypeDurationLimit,
    AMASessionExpirationTypeInvalid,
    AMASessionExpirationTypePastDate,
};

@interface AMASessionExpirationHandler : NSObject

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithConfiguration:(AMAMetricaConfiguration *)configuration APIKey:(NSString *)apiKey;

/**
 Determines the expiration type of a given AMASession at a particular point in time.
 
 This method evaluates the state of a session at the given date and determines its expiration type.
 This assessment is based on certain session attributes, such as its start and pause times, and
 also considers configuration parameters like maximum session duration and session timeout.
 The method helps to manage session lifecycles and optimizes session handling performance.
 
 @param session The AMASession object to evaluate. If the session is nil,
 the method returns AMASessionExpirationTypeInvalid.
 @param date The point in time at which to evaluate the session's state.
 
 @return AMASessionExpirationType
 - AMASessionExpirationTypeInvalid: if the session is nil
 - AMASessionExpirationTypePastDate: if the session was started in the future
 - AMASessionExpirationTypeDurationLimit: if the session has exceeded its maximum duration
 - AMASessionExpirationTypeTimeout: if the session has exceeded its timeout limit
 - AMASessionExpirationTypeNone: if none of the above conditions are met
 */
- (AMASessionExpirationType)expirationTypeForSession:(nullable AMASession *)session withDate:(NSDate *)date;

@end

NS_ASSUME_NONNULL_END


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(ReporterConfiguration)
@interface AMAReporterConfiguration : NSObject <NSCopying, NSMutableCopying>

/** Application key used to initialize the configuration.
 */
@property (nonatomic, copy, nullable, readonly) NSString *APIKey;

/** A boolean value indicating whether data sending to the AppMetrica server is enabled.

 @note Disabling this option doesn't affect data sending from the main APIKey.

 By default, the data sending is enabled.
 */
@property (nonatomic, assign, readonly) BOOL dataSendingEnabled;

/** Session timeout (in seconds).
 Time interval which determines for how long the application is considered active after being resigned.
 */
@property (nonatomic, assign, readonly) NSUInteger sessionTimeout;

/** Time interval between events dispatch (in seconds).
 */
@property (nonatomic, assign, readonly) NSUInteger dispatchPeriod;

/** Maximum number of reports stored in the database.

 Acceptable values are in the range of [100; 10000]. If passed value is outside of the range, AppMetrica automatically
 trims it to closest border value.

 @note Different apiKeys use different databases and can have different limits of reports count.
 The parameter only affects the configuration created for that APIKey.
 To set the parameter for the main APIKey, see `AMAAppMetricaConfiguration.maxReportsInDatabaseCount`.

 By default, the parameter value is 1000.
 */
@property (nonatomic, assign, readonly) NSUInteger maxReportsInDatabaseCount;

/** Events dispatch is triggered when events count reaches maxReportsCount.
 */
@property (nonatomic, assign, readonly) NSUInteger maxReportsCount;

/** Logging activation status.
 */
@property (nonatomic, assign, readonly, getter=areLogsEnabled) BOOL logsEnabled;

/** Sets the ID of the user profile.

 @warning The value can contain up to 200 characters.
 */
@property (nonatomic, copy, nullable, readonly) NSString *userProfileID;

/** Initialize configuration with specified Application key.

 @param APIKey Application key that is issued during application registration in AppMetrica.
 Application key must be a hexadecimal string in format xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.
 The key can be requested or checked at https://appmetrica.io
 */
- (nullable instancetype)initWithAPIKey:(NSString *)APIKey;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_SWIFT_NAME(MutableReporterConfiguration)
@interface AMAMutableReporterConfiguration : AMAReporterConfiguration

/** A boolean value indicating whether data sending to the AppMetrica server is enabled.

 @note Disabling this option doesn't affect data sending from the main APIKey.

 By default, the data sending is enabled.
 */
@property (nonatomic, assign) BOOL dataSendingEnabled;

/** Session timeout (in seconds).
 Time interval which determines for how long the application is considered active after being resigned.
 */
@property (nonatomic, assign) NSUInteger sessionTimeout;

/** Time interval between events dispatch (in seconds).
 */
@property (nonatomic, assign) NSUInteger dispatchPeriod;

/** Maximum number of reports stored in the database.

 Acceptable values are in the range of [100; 10000]. If passed value is outside of the range, AppMetrica automatically
 trims it to closest border value.

 @note Different apiKeys use different databases and can have different limits of reports count.
 The parameter only affects the configuration created for that APIKey.
 To set the parameter for the main APIKey, see `AMAAppMetricaConfiguration.maxReportsInDatabaseCount`.

 By default, the parameter value is 1000.
 */
@property (nonatomic, assign) NSUInteger maxReportsInDatabaseCount;

/** Events dispatch is triggered when events count reaches maxReportsCount.
 */
@property (nonatomic, assign) NSUInteger maxReportsCount;

/** Enables/disables logging.

 By default logging is disabled.
 */
@property (nonatomic, assign, getter=areLogsEnabled) BOOL logsEnabled;

/** Sets the ID of the user profile.

 @warning The value can contain up to 200 characters.
 */
@property (nonatomic, copy, nullable) NSString *userProfileID;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

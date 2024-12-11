
#import <Foundation/Foundation.h>

@class CLLocation;
@class AMAAppMetricaPreloadInfo;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(AppMetricaConfiguration)
@interface AMAAppMetricaConfiguration : NSObject

/** Initialize configuration with specified Application key.
 For invalid Application initialization returns nil in release and raises an exception in debug.

 @param APIKey Application key that is issued during application registration in AppMetrica.
 Application key must be a hexadecimal string in format xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.
 The key can be requested or checked at https://appmetrica.io
 */
- (nullable instancetype)initWithAPIKey:(NSString *)APIKey;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/** Get Application key used to initialize the configuration.
 */
@property (nonatomic, copy, readonly) NSString *APIKey;

/** Whether first activation of AppMetrica should be considered as app update or new app install.
 If this option is enabled the first call of +[AMAAppMetrica activateWithApiKey:] or
 +[AMAAppMetrica activateWithConfiguration:] will be considered as an application update.

 By default this option is disabled.
 */
@property (nonatomic, assign) BOOL handleFirstActivationAsUpdate;

/** Whether activation of AppMetrica should be considered as the start of a session.
 If this option is disabled session starts at UIApplicationDidBecomeActiveNotification.

 The option is disabled by default. Enable this property if you want events that are reported after activation to join
 the current session.
 */
@property (nonatomic, assign) BOOL handleActivationAsSessionStart;

/** Whether AppMetrica should automatically track session starts and ends.
 AppMetrica uses UIApplicationDidBecomeActiveNotification and UIApplicationWillResignActiveNotification notifications
 to track sessions.

 The maximum length of the session is 24 hours. To continue the session after 24 hours, you should manually
 invoke the resumeSession method.

 The option is enabled by default. If the option is disabled, you should manually control the session
 using pauseSession and resumeSession methods.
 */
@property (nonatomic, assign) BOOL sessionsAutoTracking;

/** A boolean value indicating whether data sending to the AppMetrica server is enabled.

 @note Disabling this option also turns off data sending from the reporters that initialized for different APIKey.

 By default, the data sending is enabled.
 */
@property (nonatomic, assign) BOOL dataSendingEnabled;

/** Maximum number of reports stored in the database.

 Acceptable values are in the range of [100; 10000]. If passed value is outside of the range, AppMetrica automatically
 trims it to closest border value.

 @note Different apiKeys use different databases and can have different limits of reports count.
 The parameter only affects the configuration created for that APIKey.
 To set the parameter for a different APIKey, see `AMAReporterConfiguration.maxReportsInDatabaseCount`

 By default, the parameter value is 1000.
 */
@property (nonatomic, assign) NSUInteger maxReportsInDatabaseCount;

/** Enable/disable location reporting to AppMetrica.
 If enabled and location set via setLocation: method - that location would be used.
 If enabled and location is not set via setLocation,
 but application has appropriate permission - CLLocationManager would be used to acquire location data.

 Enabled by default.
 */
@property (nonatomic, assign) BOOL locationTracking;

/** Enable/disable background location updates tracking.

 Disabled by default.
 To enable background location updates tracking, set the property value to YES.
 @see https://developer.apple.com/reference/corelocation/cllocationmanager/1620568-allowsbackgroundlocationupdates
 */
@property (nonatomic, assign) BOOL allowsBackgroundLocationUpdates;

/** Enable/disable accurate location retrieval for internal location manager.

 Disabled by default.
 Has effect only when locationTrackingEnabled is 'YES', and location is not set manually.
 */
@property (nonatomic, assign) BOOL accurateLocationTracking;

/** Set/get custom dispatch period. Interval in seconds between sending events to the server.
 By default, 90 seconds. Setting to 0 seconds prevents library from sending events automatically using timer.
 */
@property (nonatomic, assign) NSUInteger dispatchPeriod;

/** Set/get location to AppMetrica
 To enable AppMetrica to use this location trackLocationEnabled should be 'YES'

 By default is nil
 */
@property (nonatomic, strong, nullable) CLLocation *customLocation;

/** Set/get session timeout (in seconds).
 Time limit before the application is considered inactive.
 Minimum accepted value is 10 seconds. All passed values below 10 seconds automatically become 10 seconds.

 By default, the session times out if the application is in background for 10 seconds.
 */
@property (nonatomic, assign) NSUInteger sessionTimeout;

/** Set/get the arbitrary application version for AppMetrica to report.

 By default, the application version is set in the app configuration file Info.plist (CFBundleShortVersionString).
 */
@property (nonatomic, copy, nullable) NSString *appVersion;

/** Enable/disable logging.

 By default logging is disabled.
 */
@property (nonatomic, assign, getter=areLogsEnabled) BOOL logsEnabled;

/** Set/get preload info, which is used for tracking preload installs.
 Additional info could be https://appmetrica.io

 By default is nil.
 */
@property (nonatomic, copy, nullable) AMAAppMetricaPreloadInfo *preloadInfo;

/**
 Enables/disables auto tracking of inapp purchases.

 By default is enabled.
 */
@property (nonatomic, assign) BOOL revenueAutoTrackingEnabled;

/**
 Enables/disables app open auto tracking.
 By default is enabled.

 Set this flag to YES to track URLs that open the app.
 @note Auto tracking will only capture links that open the app. Those that are clicked on while
 the app is open will be ignored. If you need to track them as well use manual reporting as described
 [here](https://appmetrica.io/docs/mobile-sdk-dg/concepts/ios-operations.html#deeplink-tracking)
 */
@property (nonatomic, assign) BOOL appOpenTrackingEnabled;

/** Sets the ID of the user profile.

 @warning The value can contain up to 200 characters.
 */
@property (nonatomic, copy, nullable) NSString *userProfileID;

/** Set/get the maximum number of stored events. Minimum number of cached events that causes reports to be automatically sent.
 By default, events are sent automatically when there are at least 7 items in the storage.
 Setting to 0 value prevents library from sending events automatically upon reaching specified number of events in the storage.
 */
@property (nonatomic, assign) NSUInteger maxReportsCount;

/** Set/get arbitrary application build number for AppMetrica to report.

 If not set, AppMetrica will use the application build number set in the app configuration file Info.plist (CFBundleVersion).
 Build number value should be a numeric string that can be converted to an positive integer.
 */
@property (nonatomic, copy, nullable) NSString *appBuildNumber;

/** Set/get proxy urls for AppMetrica to use for startup requests.
 */
@property (nonatomic, copy, nullable) NSArray *customHosts;

/** Application environment to be set during initialization.

 Setting key - value data to be used as additional information, associated with all events from the moment of activation.
 If value is nil, previously set key-value is removed. Does nothing if key hasn't been added.
 */
@property (nonatomic, copy, nullable) NSDictionary<NSString *, NSString *> *appEnvironment;

@end

NS_ASSUME_NONNULL_END

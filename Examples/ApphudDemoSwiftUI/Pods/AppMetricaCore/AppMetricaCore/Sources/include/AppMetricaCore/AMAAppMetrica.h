#import <Foundation/Foundation.h>

@class CLLocation;
@class AMAAppMetricaConfiguration;
@class AMAReporterConfiguration;
@class AMAUserProfile;
@class AMARevenueInfo;
@class AMAECommerce;
@class AMAAdRevenueInfo;
@protocol AMAAppMetricaReporting;
@protocol AMAAppMetricaPlugins;

#if !TARGET_OS_TV
@protocol AMAJSControlling;
#endif

NS_ASSUME_NONNULL_BEGIN

typedef NSString *AMAStartupKey NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(StartupKey);

extern AMAStartupKey const kAMAUUIDKey NS_SWIFT_NAME(uuidKey);
extern AMAStartupKey const kAMADeviceIDKey;
extern AMAStartupKey const kAMADeviceIDHashKey;

typedef NSString *AMAAttributionSource NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(AttributionSource);

extern AMAAttributionSource const kAMAAttributionSourceAppsflyer;
extern AMAAttributionSource const kAMAAttributionSourceAdjust;
extern AMAAttributionSource const kAMAAttributionSourceKochava;
extern AMAAttributionSource const kAMAAttributionSourceTenjin;
extern AMAAttributionSource const kAMAAttributionSourceAirbridge;
extern AMAAttributionSource const kAMAAttributionSourceSingular;


/** Identifiers callback block

 @param identifiers  Contains any combination of following identifiers on success:
     kAMAUUIDKey
     kAMADeviceIDKey
     kAMADeviceIDHashKey (requires startup request)
     and any other custom keys that are defined in startup
 Empty dictionary may be returned if server by any reason did not provide any of above listed
 identifiers.

 @param error Error of NSURLErrorDomain. In a case of error identifiers param is nil.
 */
typedef void(^AMAIdentifiersCompletionBlock)(NSDictionary<AMAStartupKey, id> * _Nullable identifiers,
                                             NSError * _Nullable error)
NS_SWIFT_UNAVAILABLE("Use closures instead");

NS_SWIFT_NAME(AppMetrica)
@interface AMAAppMetrica : NSObject

//MARK: - Activation

/** Starts the statistics collection process.

 @param configuration Configuration combines all AppMetrica settings in one place.
 Configuration initialized with unique application key that is issued during application registration in AppMetrica.
 Application key must be a hexadecimal string in format xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.
 The key can be requested or checked at https://appmetrica.io
 */
+ (void)activateWithConfiguration:(AMAAppMetricaConfiguration *)configuration;

/** Indicates whether AppMetrica has been activated.

 @discussion Use this property to check if AppMetrica was already activated,
 typically to avoid redundant activation calls or to ensure that statistics collection has started.
*/
@property (class, assign, readonly, getter=isActivated) BOOL activated;

//MARK: - Identifier Access

/** Retrieves current UUID.

 Synchronous interface.
 */
@property (class, nonatomic, readonly) NSString *UUID;

/** Retrieves current device ID hash.

 Synchronous interface. If it is not available at the moment of call nil is returned.
 */
@property (class, nonatomic, nullable, readonly) NSString *deviceIDHash;

/** Retrieves current device ID.

 Device ID string. If it is not available at the moment of call nil is returned.
 */
@property (class, nonatomic, nullable, readonly) NSString *deviceID;

/** Getting all predefined identifiers

 @param queue Queue for the block to be dispatched to. If nil, main queue is used.
 @param block Block will be dispatched upon identifiers becoming available or in a case of error.
 Predefined identifiers are:
    kAMAUUIDKey
    kAMADeviceIDKey
    kAMADeviceIDHashKey
 If they are available at the moment of call - block is dispatched immediately. See definition
 of AMAIdentifiersCompletionBlock for more detailed information on returned types.
 */
+ (void)requestStartupIdentifiersWithCompletionQueue:(nullable dispatch_queue_t)queue
                                     completionBlock:(AMAIdentifiersCompletionBlock)block
NS_SWIFT_NAME(requestStartupIdentifiers(on:completion:));

/** Getting identifiers for specific keys

 @param keys Array of identifier keys to request. See AMACompletionBlocks.h.
 @param queue Queue for the block to be dispatched to. If nil, main queue is used.
 @param block Block will be dispatched upon identifiers becoming available or in a case of error.
 If they are available at the moment of call - block is dispatched immediately. Some keys may require
 a network request to startup. See definition of AMAIdentifiersCompletionBlock for more detailed
 information on returned types.
 */
+ (void)requestStartupIdentifiersWithKeys:(NSArray<AMAStartupKey> *)keys
                          completionQueue:(nullable dispatch_queue_t)queue
                          completionBlock:(AMAIdentifiersCompletionBlock)block
NS_SWIFT_NAME(requestStartupIdentifiers(for:on:completion:));

//MARK: - Event Reporting

/** Reports a custom event.

 @param name Short name or description of the event.
 @param onFailure Block to be executed if an error occurs while reporting, the error is passed as block argument.
 */
+ (void)reportEvent:(NSString *)name
          onFailure:(nullable void (^)(NSError *error))onFailure
NS_SWIFT_NAME(reportEvent(name:onFailure:));

/** Reports a custom event with additional parameters.

 @param name Short name or description of the event.
 @param params Dictionary of name/value pairs that should be sent to the server.
 @param onFailure Block to be executed if an error occurs while reporting, the error is passed as block argument.
 */
+ (void)reportEvent:(NSString *)name
         parameters:(nullable NSDictionary *)params
          onFailure:(nullable void (^)(NSError *error))onFailure
NS_SWIFT_NAME(reportEvent(name:parameters:onFailure:));

/** Sends information about the user profile.

 @param userProfile The `AMAUserProfile` object. Contains user profile information.
 @param onFailure Block to be executed if an error occurs while reporting, the error is passed as block argument.
 */
+ (void)reportUserProfile:(AMAUserProfile *)userProfile
                onFailure:(nullable void (^)(NSError *error))onFailure
NS_SWIFT_NAME(reportUserProfile(_:onFailure:));

/** Sends information about the purchase.

 @param revenueInfo The `AMARevenueInfo` object. Contains purchase information
 @param onFailure Block to be executed if an error occurs while reporting, the error is passed as block argument.
 */
+ (void)reportRevenue:(AMARevenueInfo *)revenueInfo
            onFailure:(nullable void (^)(NSError *error))onFailure
NS_SWIFT_NAME(reportRevenue(_:onFailure:));

/**
 * Sends information about ad revenue.
 * @note See `AMAAdRevenueInfo` for more info.
 *
 * @param adRevenue Object containing the information about ad revenue.
 * @param onFailure Block to be executed if an error occurs while sending ad revenue,
 *                  the error is passed as block argument.
 */
+ (void)reportAdRevenue:(AMAAdRevenueInfo *)adRevenue
              onFailure:(nullable void (^)(NSError *error))onFailure
NS_SWIFT_NAME(reportAdRevenue(_:onFailure:));

/** Sends information about the E-commerce event.

 @note See `AMAEcommerce` for all possible E-commerce events.

 @param eCommerce The object of `AMAECommerce` class.
 @param onFailure Block to be executed if an error occurs while reporting, the error is passed as block argument.
 */
+ (void)reportECommerce:(AMAECommerce *)eCommerce
              onFailure:(nullable void (^)(NSError *error))onFailure
NS_SWIFT_NAME(reportECommerce(_:onFailure:));

/** Sends information about the external attribution.

 This method is used to report attribution from other SDKs.
 Possible sources include Appsflyer, Adjust, Kochava, Tenjin, Airbridge, Singular.

 @note The `attribution` dictionary should be JSON-convertible. If it is not, the `onFailure` block will be called with an error.

 @param attribution The dictionary containing the attribution data.
 @param source The source of the attribution data.
 @param onFailure Block to be executed if an error occurs during reporting. The error is passed as a block argument.
 */
+ (void)reportExternalAttribution:(NSDictionary *)attribution
                           source:(AMAAttributionSource)source
                        onFailure:(nullable void (^)(NSError *error))onFailure
NS_SWIFT_NAME(reportExternalAttribution(_:from:onFailure:));

//MARK: - Web View Reporting

#if !TARGET_OS_TV
/**
 * Adds interface named "AppMetrica" to WKWebView's JavaScript.
 * It enabled you to report events to AppMetrica from JavaScript code.
 * For use you need an explicit import of AMAWebKit:
 * ```
 * #import <AppMetricaWebKit/AppMetricaWebKit.h>
 * ```
 * @note
 * This method must be called before adding any WKUserScript that uses AppMetrica interface or creating WKWebView.
 * Example:
 * ```
 * WKWebViewConfiguration *webConfiguration = [WKWebViewConfiguration new];
 * WKUserContentController *userContentController = [WKUserContentController new];
 * AMAJSController *jsController = [[AMAJSController alloc] initWithUserContentController:userContentController];
 * [AMAAppMetrica setupWebViewReporting:jsController
                              onFailure:nil];
 * [userContentController addUserScript:self.scriptWithAppMetrica];
 * webConfiguration.userContentController = userContentController;
 * self.webView = [[WKWebView alloc] initWithFrame:CGRectZero configuration:webConfiguration];
 * ```
 * After web view reporting is initialized you can report event to AppMetrica from your JavaScript code the following way:
 * ```
 * function reportToAppMetrica(eventName, eventValue) {
 *     AppMetrica.reportEvent(eventName, eventValue);
 * }
 * ```
 * Here eventName is any non-empty String, eventValue is a JSON String, may be null or empty.
 *
 * @param controller AMAJSController object from AMAWebKit
 * @param onFailure Block to be executed if an error occurs while initializing web view reporting,
 *                  the error is passed as block argument.
 */
+ (void)setupWebViewReporting:(id<AMAJSControlling>)controller
                    onFailure:(nullable void (^)(NSError *error))onFailure
NS_SWIFT_NAME(setupWebViewReporting(with:onFailure:));
#endif

//MARK: - Session Management

/** Resumes the last session or creates a new one if it has been expired.

 @warning You should disable the automatic tracking before using this method.
 See the sessionsAutoTracking property of AMAAppMetricaConfiguration.
 */
+ (void)resumeSession;

/** Pauses the current session.
 All events reported after calling this method and till the session timeout will still join this session.

 @warning You should disable the automatic tracking before using this method.
 See the sessionsAutoTracking property of AMAAppMetricaConfiguration.
 */
+ (void)pauseSession;

//MARK: - Reporters

/** Returns id<AMAAppMetricaReporting> that can send events to specific API key.
 To customize configuration of reporter activate with 'activateReporterWithConfiguration:' method first.

 @param APIKey Api key to send events to.
 @return id<AMAAppMetricaReporting> that conforms to AMAAppMetricaReporting and handles
 sending events to specified apikey
 */
+ (nullable id<AMAAppMetricaReporting>)reporterForAPIKey:(NSString *)APIKey NS_SWIFT_NAME(reporter(for:));

/** Activates reporter with specific configuration.

 @param configuration Configuration combines all reporter settings in one place.
 Configuration initialized with unique application key that is issued during application registration in AppMetrica.
 Application key must be a hexadecimal string in format xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx.
 The key can be requested or checked at https://appmetrica.io
 */
+ (void)activateReporterWithConfiguration:(AMAReporterConfiguration *)configuration;

//MARK: - Location Tracking

/** Enables/disables location reporting to AppMetrica.

 If enabled and location set via `customLocation` property - that location would be used.
 If enabled and location is not set via setLocation,
 but application has appropriate permission - CLLocationManager would be used to acquire location data.

 @note Enabled by default.
 */
@property (class, nonatomic, getter=isLocationTrackingEnabled) BOOL locationTrackingEnabled;

/** Controls the accuracy of the location tracking used by the internal location manager.

 When set to `YES`, the location manager attempts to use the most accurate location data available.
 This property only takes effect if `isLocationTrackingEnabled` is set to `YES` and the location
 has not been manually set using the `customLocation` property.
 */
@property (class, nonatomic, getter=isAccurateLocationTrackingEnabled) BOOL accurateLocationTrackingEnabled;

/** Enable/disable background location updates tracking.

 @note Disabled by default.
 @see https://developer.apple.com/reference/corelocation/cllocationmanager/1620568-allowsbackgroundlocationupdates
 */
@property (class, nonatomic) BOOL allowsBackgroundLocationUpdates;

/** Sets a custom location for AppMetrica tracking.

 @note To utilize this custom location, ensure `isLocationTrackingEnabled` is set to `YES`.
 */
@property (class, nonatomic, nullable) CLLocation *customLocation;

//MARK: - User Profile

/** ID of the user profile.

 @warning The value can contain up to 200 characters
 */
@property (class, nonatomic, nullable) NSString *userProfileID;

//MARK: - URL Tracking

/** Handles the URL that has opened the application.
 Reports the URL for deep links tracking.

 @param URL URL that has opened the application.
 */
+ (void)trackOpeningURL:(NSURL *)URL NS_SWIFT_NAME(trackOpeningURL(_:));

//MARK: - Data Sending and Handling

/** Enables/disables data sending to the AppMetrica server.

 The `enabled` value can be overridden by the configuration settings during the activation process if it was set before activation.
 After activation, this method's value overrides the configuration's value.

 @note Disabling this option also turns off data sending from the reporters that initialized for different APIKey.

 @param enabled Flag indicating whether the data sending is enabled. By default, the sending is enabled.
 */
+ (void)setDataSendingEnabled:(BOOL)enabled;

/** Sends all stored events from the buffer.

 AppMetrica SDK doesn't send events immediately after they occurred. It stores events data in the buffer.
 This method sends all the data from the buffer and flushes it.
 Use the method to force stored events sending after important checkpoints of user scenarios.

 @warning Frequent use of the method can lead to increasing outgoing internet traffic and energy consumption.
 */
+ (void)sendEventsBuffer;

//MARK: - Environment

/** Setting key - value data to be used as additional information, associated with all future events.
 If value is nil, previously set key-value is removed. Does nothing if key hasn't been added.
 To ensure that data is associated with all events from the moment of activation, specify the appEnvironment property within AMAAppMetricaConfiguration.

 @param value The app environment value.
 @param key The app environment key.
 */
+ (void)setAppEnvironmentValue:(nullable NSString *)value
                        forKey:(NSString *)key NS_SWIFT_NAME(setAppEnvironment(_:forKey:));

/** Clearing app environment, e.g. removes all key - value data associated with all future events.
 */
+ (void)clearAppEnvironment;

//MARK: - Utility

/** Retrieves current version of library.
 */
@property (class, nonatomic, readonly) NSString *libraryVersion;

@end

NS_ASSUME_NONNULL_END

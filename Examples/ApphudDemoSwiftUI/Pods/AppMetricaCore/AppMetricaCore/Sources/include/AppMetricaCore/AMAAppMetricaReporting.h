
#import <Foundation/Foundation.h>

@class AMAUserProfile;
@class AMARevenueInfo;
@class AMAECommerce;
@class AMAAdRevenueInfo;
@protocol AMAAppMetricaPluginReporting;

#if !TARGET_OS_TV
@protocol AMAJSControlling;
#endif

NS_ASSUME_NONNULL_BEGIN

/** `AMAAppMetricaReporting` protocol groups methods that are used by custom reporting objects.
 */
NS_SWIFT_NAME(AppMetricaReporting)
@protocol AMAAppMetricaReporting  <NSObject>

//MARK: - Event Reporting

/** Reports a custom event.

 @param name Short name or description of the event.
 @param onFailure Block to be executed if an error occurs while reporting, the error is passed as block argument.
 */
- (void)reportEvent:(NSString *)name
          onFailure:(nullable void (^)(NSError *error))onFailure
NS_SWIFT_NAME(reportEvent(name:onFailure:));

/** Reports a custom event with additional parameters.

 @param name Short name or description of the event.
 @param params Dictionary of name/value pairs that must be sent to the server.
 @param onFailure Block to be executed if an error occurs while reporting, the error is passed as block argument.
 */
- (void)reportEvent:(NSString *)name
         parameters:(nullable NSDictionary *)params
          onFailure:(nullable void (^)(NSError *error))onFailure
NS_SWIFT_NAME(reportEvent(name:parameters:onFailure:));

/** Sends information about the user profile.

 @param userProfile The `AMAUserProfile` object. Contains user profile information.
 @param onFailure Block to be executed if an error occurs while reporting, the error is passed as block argument.
 */
- (void)reportUserProfile:(AMAUserProfile *)userProfile
                onFailure:(nullable void (^)(NSError *error))onFailure
NS_SWIFT_NAME(reportUserProfile(_:onFailure:));

/** Sends information about the purchase.

 @param revenueInfo The `AMARevenueInfo` object. Contains purchase information.
 @param onFailure Block to be executed if an error occurs while reporting, the error is passed as block argument.
 */
- (void)reportRevenue:(AMARevenueInfo *)revenueInfo
            onFailure:(nullable void (^)(NSError *error))onFailure
NS_SWIFT_NAME(reportRevenue(_:onFailure:));

/** Sends information about the E-commerce event.

 @note See `AMAEcommerce` for all possible E-commerce events.

 @param eCommerce The object of `AMAECommerceEvent` protocol created with `AMAEcommerce` class.
 @param onFailure Block to be executed if an error occurs while reporting, the error is passed as block argument.
 */
- (void)reportECommerce:(AMAECommerce *)eCommerce
              onFailure:(nullable void (^)(NSError *error))onFailure
NS_SWIFT_NAME(reportECommerce(_:onFailure:));

/**
 * Sends information about ad revenue.
 * @note See `AMAAdRevenueInfo` for more info.
 *
 * @param adRevenue Object containing the information about ad revenue.
 * @param onFailure Block to be executed if an error occurs while sending ad revenue,
 *                  the error is passed as block argument.
 */
- (void)reportAdRevenue:(AMAAdRevenueInfo *)adRevenue
              onFailure:(nullable void (^)(NSError *error))onFailure
NS_SWIFT_NAME(reportAdRevenue(_:onFailure:));

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
 * id<AMAAppMetricaReporting> reporter = [AMAAppMetrica reporterForAPIKey:apiKey];
 * [reporter setupWebViewReporting:jsController
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
- (void)setupWebViewReporting:(id<AMAJSControlling>)controller
                    onFailure:(nullable void (^)(NSError *error))onFailure
NS_SWIFT_NAME(setupWebViewReporting(with:onFailure:));
#endif

//MARK: - Session Management

/** Resumes last session or creates a new one if it has been expired.
 Should be used when auto tracking of application state is unavailable or is different.
 */
- (void)resumeSession;

/** Pauses current session.
 All events reported after calling this method and till the session timeout will still join this session.
 Should be used when auto tracking of application state is unavailable or is different.
 */
- (void)pauseSession;

//MARK: - User Profile

/** Sets the ID of the user profile.

 @warning The value can contain up to 200 characters.
 */
@property (nonatomic, strong, nullable) NSString *userProfileID;

//MARK: - Data Sending and Handling

/** Enables/disables data sending to the AppMetrica server.

 @note Disabling this option doesn't affect data sending from the main APIKey.

 @param enabled Flag indicating whether the data sending is enabled. By default, the sending is enabled.
 */
- (void)setDataSendingEnabled:(BOOL)enabled;

/** Sends all stored events from the buffer.

 AppMetrica SDK doesn't send events immediately after they occurred. It stores events data in the buffer.
 This method sends all the data from the buffer and flushes it.
 Use the method to force stored events sending after important checkpoints of user scenarios.

 @warning Frequent use of the method can lead to increasing outgoing internet traffic and energy consumption.
 */
- (void)sendEventsBuffer;

//MARK: - Environment

/** Setting key - value data to be used as additional information, associated with all future events.
 If value is nil previously set key-value is removed, does nothing if key hasn't been added.

 @param value The app environment value.
 @param key The app environment key.
 */
- (void)setAppEnvironmentValue:(nullable NSString *)value
                        forKey:(NSString *)key NS_SWIFT_NAME(setAppEnvironment(_:forKey:));

/** Clearing app environment, e.g. removes all key - value data associated with all future events.
 */
- (void)clearAppEnvironment;

@end

NS_ASSUME_NONNULL_END

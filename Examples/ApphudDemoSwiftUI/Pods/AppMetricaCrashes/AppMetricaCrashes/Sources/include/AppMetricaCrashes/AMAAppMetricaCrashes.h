
#import <Foundation/Foundation.h>

#if __has_include("AMAErrorRepresentable.h")
    #import "AMAErrorRepresentable.h"
#else
    #import <AppMetricaCrashes/AMAErrorRepresentable.h>
#endif

NS_ASSUME_NONNULL_BEGIN

typedef NSString *AMACrashReportingStateKey NS_TYPED_EXTENSIBLE_ENUM NS_SWIFT_NAME(CrashReportingStateKey);

extern AMACrashReportingStateKey const kAMACrashReportingStateEnabledKey NS_SWIFT_NAME(enabledKey);
extern AMACrashReportingStateKey const kAMACrashReportingStateCrashedLastLaunchKey NS_SWIFT_NAME(crashedLastLaunchKey);

/// Type definition for the crash reporting state callback block.
///
/// The 'state' parameter is a dictionary that can contain any combination of the following keys:
/// - kAMACrashReportingStateEnabledKey: An NSNumber containing a boolean value indicating if crash reporting is enabled.
/// - kAMACrashReportingStateCrashedLastLaunchKey: An NSNumber containing a boolean value indicating if the app crashed during the last launch.
///
/// Use this block type with methods that require crash reporting state completion callbacks.
typedef void(^AMACrashReportingStateCompletionBlock)(NSDictionary<AMACrashReportingStateKey, id> * _Nullable state)
    NS_SWIFT_UNAVAILABLE("Use Swift closures.");

@protocol AMAErrorRepresentable;
@protocol AMAAppMetricaPlugins;
@protocol AMAAppMetricaCrashReporting;
@class AMAAppMetricaCrashesConfiguration;

///`AMAAppMetricaCrashes` provides error and crash reporting functionalities for integration with AppMetrica.
///
///The class offers a singleton instance and should not be subclassed. Initialize using `[AMAAppMetricaCrashes crashes]`.
///
NS_SWIFT_NAME(AppMetricaCrashes)
@interface AMAAppMetricaCrashes : NSObject

/// Accesses the singleton `AMAAppMetricaCrashes` instance.
///
/// - Returns: The singleton `AMAAppMetricaCrashes` instance.
+ (instancetype)crashes NS_SWIFT_NAME(crashes());

/// Sets the crash reporting configuration for the application.
///
/// - Parameter configuration: An `AMAAppMetricaCrashesConfiguration` object that specifies how the application should handle and report crashes.
///
/// This method allows you to customize the behavior of the crash reporting mechanism.
/// Use the properties of the `AMAAppMetricaCrashesConfiguration` class to enable or disable specific types of crash reporting, as well as customize other related settings.
/// Once set, the configuration will control how the app deals with various types of crashes and issues.
///
/// ## Example
/// ```objc
/// AMAAppMetricaCrashesConfiguration *config = [AMAAppMetricaCrashesConfiguration new];
/// config.autoCrashTracking = YES;
/// config.probablyUnhandledCrashReporting = NO;
/// config.applicationNotRespondingDetection = YES;
/// config.applicationNotRespondingWatchdogInterval = 5.0;
/// [[AMAAppMetricaCrashes crashes] setConfiguration:config];
/// ```
///
/// - SeeAlso: `AMAAppMetricaCrashesConfiguration`
- (void)setConfiguration:(AMAAppMetricaCrashesConfiguration *)configuration;

/// Reports an error of the `NSError` type to AppMetrica.
///
/// The method allows reporting of errors that follow specific limits on `domain`, `userInfo`, and other properties.
///
/// - Parameter error: The `NSError` object to report. AppMetrica uses the `domain` and `code` properties for grouping errors.
/// - Parameter onFailure: A closure that is executed if an error occurs while reporting. The error is passed as an argument to the block.
///
/// - Note: You can also include a custom backtrace in the `NSError` by using the `AMABacktraceErrorKey` constant in `userInfo`.
///
/// ## Limits
/// - `domain`: Max 200 characters.
/// - `userInfo`: Max 50 key-value pairs; max 100 characters for key length, max 2000 characters for value length.
/// - `NSUnderlyingErrorKey`: Max 10 underlying errors can be included using this key in `userInfo`.
/// - `AMABacktraceErrorKey`: Max 200 stack frames in a backtrace can be included using this key in `userInfo`.
///
/// If the value exceeds any of these limits, AppMetrica will truncate it.
- (void)reportNSError:(NSError *)error
            onFailure:(nullable void (^)(NSError *error))onFailure NS_SWIFT_NAME(report(nserror:onFailure:));

/// Reports an error of the `NSError` type with additional reporting options.
///
/// The method allows for customized error reporting, following specific limits on properties like `domain`, `userInfo`, and others.
///
/// - Parameter error: The `NSError` object to report. AppMetrica uses the `domain` and `code` properties for grouping errors.
/// - Parameter options: An `AMAErrorReportingOptions` value that specifies how the error should be reported.
/// - Parameter onFailure: A closure that is executed if an error occurs while reporting. The error is passed as an argument to the block.
///
/// - Note: You can include a custom backtrace in the `NSError` using the `AMABacktraceErrorKey` constant in `userInfo`.
///
/// ## Limits
/// - `domain`: Max 200 characters.
/// - `userInfo`: Max 50 key-value pairs; max 100 characters for key length, max 2000 characters for value length.
/// - `NSUnderlyingErrorKey`: Max 10 underlying errors can be included using this key in `userInfo`.
/// - `AMABacktraceErrorKey`: Max 200 stack frames in a backtrace can be included using this key in `userInfo`.
///
/// If any value exceeds these limits, AppMetrica will truncate it.
- (void)reportNSError:(NSError *)error
              options:(AMAErrorReportingOptions)options
            onFailure:(nullable void (^)(NSError *error))onFailure NS_SWIFT_NAME(report(nserror:options:onFailure:));

/// Reports a custom error that conforms to the `AMAErrorRepresentable` protocol.
///
/// - Parameter error: The custom error to report, which must conform to the `AMAErrorRepresentable` protocol.
/// - Parameter onFailure: A closure that is executed if an error occurs while reporting. The reporting error is passed as a closure argument.
///
/// - SeeAlso: For details on creating custom errors, refer to the `AMAErrorRepresentable` protocol documentation.
- (void)reportError:(id<AMAErrorRepresentable>)error
          onFailure:(nullable void (^)(NSError *error))onFailure NS_SWIFT_NAME(report(error:onFailure:));

/// Reports a custom error that conforms to the `AMAErrorRepresentable` protocol with additional reporting options.
///
/// - Parameter error: The custom error to report, which must conform to the `AMAErrorRepresentable` protocol.
/// - Parameter options: Additional options for reporting the error, defined in `AMAErrorReportingOptions`.
/// - Parameter onFailure: A closure that is executed if an error occurs while reporting. The reporting error is passed as a closure argument.
///
/// - SeeAlso: For details on creating custom errors, refer to the `AMAErrorRepresentable` protocol documentation.
- (void)reportError:(id<AMAErrorRepresentable>)error
            options:(AMAErrorReportingOptions)options
          onFailure:(nullable void (^)(NSError *error))onFailure NS_SWIFT_NAME(report(error:options:onFailure:));

/// Sets a key-value pair that will be associated with errors and crashes.
///
/// - Parameter value: The value you want to associate with a specific key. Setting this to `nil` will remove the previously set key-value pair.
/// - Parameter key: The key with which to associate the value.
///
/// - Note: AppMetrica uses these key-value pairs as additional information for unhandled exceptions.
- (void)setErrorEnvironmentValue:(nullable NSString *)value
                          forKey:(NSString *)key NS_SWIFT_NAME(set(errorEnvironmentValue:forKey:));

/// Clears all key-value pairs associated with errors and crashes.
///
/// - Note: This method removes all previously set key-value pairs associated with errors and crashes.
///  Using this ensures that no additional information will be attached to future unhandled exceptions unless new key-value pairs are set.
///
/// - SeeAlso: `-setErrorEnvironmentValue:forKey:` for setting individual key-value pairs.
- (void)clearErrorEnvironment;

/// Requests the current crash reporting state.
///
/// This method asynchronously fetches the current crash reporting state and returns it via a completion block.
///
/// - Parameter completionQueue: The dispatch queue on which to execute the completion block.
/// - Parameter completionBlock: A block to be executed upon completion of the request.
///
/// - SeeAlso: `AMACrashReportingStateCompletionBlock` for more information on the dictionary keys and their associated values.
- (void)requestCrashReportingStateWithCompletionQueue:(dispatch_queue_t)completionQueue
                                      completionBlock:(AMACrashReportingStateCompletionBlock)completionBlock;

/** Enable ANR monitoring with default parameters.

 Default parameters:
 - `watchdog` interval 4 seconds,
 - `ping` interval 0.1 second.

 @note Use this method to enable ANR monitoring only after the activation.
 Use the applicationNotRespondingDetection property of AMAAppMetricaCrashesConfiguration if you want to enable
 ANR monitoring at the time of activation.
 */
- (void)enableANRMonitoring;

/** Enable ANR monitoring.
 Use this method to enable ANR monitoring only after the activation.

 @param watchdog Time interval the watchdog queue would wait for the main queue response before report ANR.
 @param ping Time interval the watchdog queue would ping the main queue.

 @note Use the `applicationNotRespondingDetection` property of `AMAAppMetricaCrashesConfiguration` if you want to enable
 ANR monitoring during the activation.
 @warning A small `ping` value can lead to poor performance.
 */
- (void)enableANRMonitoringWithWatchdogInterval:(NSTimeInterval)watchdog pingInterval:(NSTimeInterval)ping;

/** Returns id<AMAAppMetricaCrashReporting> that can send errors to specific API key.

 @param apiKey Api key to send events to.
 @return id<AMAAppMetricaCrashReporting> that conforms to AMAAppMetricaCrashReporting and handles
 sending errors to specified apikey
 */
- (nullable id<AMAAppMetricaCrashReporting>)reporterForAPIKey:(NSString *)apiKey NS_SWIFT_NAME(reporter(for:));

/**
 * Creates a `AMAAppMetricaPlugins` that can send plugin events to main API key.
 * Only one `AMAAppMetricaPlugins` instance is created.
 * You can either query it each time you need it, or save the reference by yourself.
 * NOTE: to use this extension you must activate AppMetrica first
 * via `[AMAAppMetrica activateWithConfiguration:]`.
 *
 * @return plugin extension instance
 */
- (id<AMAAppMetricaPlugins>)pluginExtension;

@end

NS_ASSUME_NONNULL_END


#import <Foundation/Foundation.h>
#import "AMAErrorRepresentable.h"

NS_ASSUME_NONNULL_BEGIN

/** `AMAAppMetricaCrashReporting` protocol groups methods that are used by custom reporting errors.
 */

@protocol AMAAppMetricaPluginReporting;

NS_SWIFT_NAME(AppMetricaCrashReporting)
@protocol AMAAppMetricaCrashReporting <NSObject>

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

/**
 * Creates a `AMAAppMetricaPluginReporting` that can send plugin events to this reporter.
 * For every reporter only one `AMAAppMetricaPluginReporting` instance is created.
 * You can either query it each time you need it, or save the reference by yourself.
 *
 * @return plugin extension instance for this reporter
 */
- (id<AMAAppMetricaPluginReporting>)pluginExtension;

@end

NS_ASSUME_NONNULL_END

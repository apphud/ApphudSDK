
#import <Foundation/Foundation.h>

@class AMAPluginErrorDetails;

NS_ASSUME_NONNULL_BEGIN

/**
 * `AMAAppMetricaPluginReporting` is an extension of `AMAAppMetricaCrashReporting`.
 * Instance of object that implements `AMAAppMetricaPluginReporting` can be obtained via
 * `AMAAppMetricaCrashReporting#pluginExtension` property.
 * For every reporter only one `AMAAppMetricaPluginReporting` instance is created.
 * You can either query it each time you need it, or save the reference by yourself.
 *
 * @note See `AMAAppMetricaCrashReporting#pluginExtension`.
 */
NS_SWIFT_NAME(AppMetricaPluginReporting)
@protocol AMAAppMetricaPluginReporting <NSObject>

/**
 Sends unhandled error.
 @note See `AMAPluginErrorDetails` for more information.

 @param errorDetails Object describing the error.
 @param onFailure Block to be executed if an error occurs while reporting, the error is passed as block argument.
 */
- (void)reportUnhandledException:(AMAPluginErrorDetails *)errorDetails
                       onFailure:(nullable void (^)(NSError *error))onFailure
NS_SWIFT_NAME(reportUnhandledException(exception:onFailure:));

/**
 Sends custom error. Backtrace will be used for grouping. If you want to customize grouping use `reportError:details:onFailure`.
 @note See `AMAPluginErrorDetails` for more information.

 @param errorDetails Object describing the error.
                     @note For the error to be sent, errorDetails must contain non empty stacktrace.
                     Otherwise it will be ignored. If you can't provide stacktrace,
                     use `[AMAAppMetricaPluginReporting reportErrorWithIdentifier:message:details:onFailure:]`
                     with filled identifier.
 @param message Short description or name of the error.
 @param onFailure Block to be executed if an error occurs while reporting, the error is passed as block argument.
 */
- (void)reportError:(AMAPluginErrorDetails *)errorDetails
            message:(nullable NSString *)message
          onFailure:(nullable void (^)(NSError *error))onFailure
NS_SWIFT_NAME(reportError(error:message:onFailure:));

/**
 Sends custom error with message. Identifier will be used for grouping errors.
 If you want to use backtrace for grouping instead use `reportError:message:onFailure`.
 @note See `AMAPluginErrorDetails` for more information.

 @param identifier Identifier used for grouping.
 @param message Short description or name of the error.
 @param errorDetails Object describing the error.
 @param onFailure Block to be executed if an error occurs while reporting, the error is passed as block argument.
 */
- (void)reportErrorWithIdentifier:(NSString *)identifier
                          message:(nullable NSString *)message
                          details:(nullable AMAPluginErrorDetails *)errorDetails
                        onFailure:(nullable void (^)(NSError *error))onFailure
NS_SWIFT_NAME(reportError(identifier:message:error:onFailure:));

@end

NS_ASSUME_NONNULL_END

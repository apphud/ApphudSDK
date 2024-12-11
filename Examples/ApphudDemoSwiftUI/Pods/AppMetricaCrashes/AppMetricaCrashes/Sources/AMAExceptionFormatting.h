
#import <Foundation/Foundation.h>

@class AMAErrorModel;
@class AMAPluginErrorDetails;

@protocol AMAExceptionFormatting <NSObject>

/// Returns formatted `NSData` for the given exception.
///
/// This function is currently unused but may be useful. Used for legacy NSString errors.
///
/// - Parameters:
///   - exception: The `NSException` object to be formatted.
///   - error: A pointer to an `NSError` object for error reporting.
///
/// - Returns: `NSData` if successful or if only non-critical errors occur; `nil` if a critical error occurs.
- (NSData *)formattedException:(NSException *)exception error:(NSError **)error;

/// Returns formatted `NSData` for the given model error.
///
/// - Parameters:
///   - modelError: The `AMAErrorModel` object to be formatted.
///   - error: A pointer to an `NSError` object for error reporting.
///
/// - Returns: `NSData` if successful or if only non-critical errors occur; `nil` if a critical error occurs.
- (NSData *)formattedError:(AMAErrorModel *)modelError error:(NSError **)error;

/// Returns formatted `NSData` for the given crash error details.
///
/// - Parameters:
///   - errorDetails: The `AMAPluginErrorDetails` object related to a crash to be formatted.
///   - bytesTruncated: A pointer to a `NSUInteger` for tracking bytes truncated during formatting.
///   - error: A pointer to an `NSError` object for error reporting.
///
/// - Returns: `NSData` if successful or if only non-critical errors occur; `nil` if a critical error occurs.
- (NSData *)formattedCrashErrorDetails:(AMAPluginErrorDetails *)errorDetails
                        bytesTruncated:(NSUInteger *)bytesTruncated
                                 error:(NSError **)error;

/// Returns formatted `NSData` for the given error details.
///
/// - Parameters:
///   - errorDetails: The `AMAPluginErrorDetails` object related to a general error to be formatted.
///   - bytesTruncated: A pointer to a `NSUInteger` for tracking bytes truncated during formatting.
///   - error: A pointer to an `NSError` object for error reporting.
///
/// - Returns: `NSData` if successful or if only non-critical errors occur; `nil` if a critical error occurs.
- (NSData *)formattedErrorErrorDetails:(AMAPluginErrorDetails *)errorDetails
                        bytesTruncated:(NSUInteger *)bytesTruncated
                                 error:(NSError **)error;

/// Returns formatted `NSData` for custom error details with an identifier.
///
/// - Parameters:
///   - errorDetails: The `AMAPluginErrorDetails` object related to a custom error to be formatted.
///   - identifier: A custom identifier for the error.
///   - bytesTruncated: A pointer to a `NSUInteger` for tracking bytes truncated during formatting.
///   - error: A pointer to an `NSError` object for error reporting.
///
/// - Returns: `NSData` if successful or if only non-critical errors occur; `nil` if a critical error occurs.
- (NSData *)formattedCustomErrorErrorDetails:(AMAPluginErrorDetails *)errorDetails
                                  identifier:(NSString *)identifier
                              bytesTruncated:(NSUInteger *)bytesTruncated
                                       error:(NSError **)error;


@end

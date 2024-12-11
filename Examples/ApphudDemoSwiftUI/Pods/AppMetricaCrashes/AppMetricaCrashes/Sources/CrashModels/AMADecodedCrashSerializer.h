
#import <Foundation/Foundation.h>

@class AMADecodedCrash;
@class AMADecodedCrashValidator;
@class AMAInternalEventsReporter;

@interface AMADecodedCrashSerializer : NSObject

/// Returns `NSData` for the given decoded crash.
///
/// This method will validate the `decodedCrash` and serialize it into `NSData`. In the case of critical errors,
/// the `error` parameter will be populated, and the method will return `nil`. For non-critical errors, the `error`
/// parameter will still be populated, but the method will return the `NSData`.
///
/// - Parameters:
///   - decodedCrash: The decoded crash object to be serialized.
///   - error: A pointer to an `NSError` object. For critical errors, this will be populated, and `nil` will be returned.
///            For non-critical errors, this will be populated but the method will still return data.
///
/// - Returns: `NSData` if serialization is successful or if only non-critical errors occur; `nil` if a critical error occurs.
- (NSData *)dataForCrash:(AMADecodedCrash *)decodedCrash error:(NSError **)error;

@end


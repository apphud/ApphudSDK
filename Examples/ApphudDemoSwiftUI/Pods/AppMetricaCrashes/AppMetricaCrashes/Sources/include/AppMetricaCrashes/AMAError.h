
#import <Foundation/Foundation.h>

#if __has_include("AMAErrorRepresentable.h")
    #import "AMAErrorRepresentable.h"
#else
    #import <AppMetricaCrashes/AMAErrorRepresentable.h>
#endif

NS_ASSUME_NONNULL_BEGIN

/** The default implementation of the `AMAErrorRepresentable` protocol.
 */
NS_SWIFT_NAME(AppMetricaError)
@interface AMAError : NSObject <AMAErrorRepresentable>

/** Creates the error instance with its ID.
 
 @note For more information, see `AMAErrorRepresentable`.
 
 @param identifier Unique error identifier
 @return The `AMAError` instance
 */
+ (instancetype)errorWithIdentifier:(NSString *)identifier;

/** Creates the error instance with its ID and other properties.
 
 @note For more information on parameters, see `AMAErrorRepresentable`.
 
 @param identifier Unique error identifier
 @param message Arbitrary description of the error
 @param parameters Addittional error parameters
 @return The `AMAError` instance
 */
+ (instancetype)errorWithIdentifier:(NSString *)identifier
                            message:(nullable NSString *)message
                         parameters:(nullable NSDictionary<NSString *, id> *)parameters;

/** Creates the error instance with its ID and other properties.

 @note For more information on parameters, see `AMAErrorRepresentable`.

 @param identifier Unique error identifier
 @param message Arbitrary description of the error
 @param parameters Addittional error parameters
 @param backtrace Custom error backtrace
 @param underlyingError Underlying error instance that conforms to the `AMAErrorRepresentable` protocol
 @return The `AMAError` instance
 */
+ (instancetype)errorWithIdentifier:(NSString *)identifier
                            message:(nullable NSString *)message
                         parameters:(nullable NSDictionary<NSString *, id> *)parameters
                          backtrace:(nullable NSArray<NSNumber *> *)backtrace
                    underlyingError:(nullable id<AMAErrorRepresentable>)underlyingError;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END


#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** A key from the user info dictionary of NSError. It should contain error backtrace.
 You can get it from `NSThread.callStackReturnAddresses` (Objective-C) or `Thread.callStackReturnAddresses`(Swift).
 
 AppMetrica automatically parses the passed value.
 */
extern NSErrorUserInfoKey const AMABacktraceErrorKey NS_SWIFT_NAME(BacktraceErrorKey);

/** Reporting options enumeration.
 */
typedef NS_OPTIONS(NSUInteger, AMAErrorReportingOptions) {
    
    /** Option that does not attach the backtrace of the current thread to an error. This option might speed up the reporting.
     */
    AMAErrorReportingOptionsNoBacktrace = 1 << 0,
} NS_SWIFT_NAME(ErrorReportingOptions);

/** The protocol for errors that can be reported to AppMetrica.
 Each error instance should have the specified `identifier` property. AppMetrica uses the property value to group errors.
 
 All reported information on error is displayed in the AppMetrica report.
 
 You can implement this protocol to send custom errors. Also, you can use the default protocol implementation `AMAError`.
 */
NS_SWIFT_NAME(ErrorRepresentable)
@protocol AMAErrorRepresentable <NSObject>

#pragma mark - Required

@required

/** Unique error identifier.
 AppMetrica uses it for grouping.
 
 The maximum length is 300 characters.
 If the value exceeds the limit, AppMetrica truncates it.
 
 @note AppMetrica doesn't use the IDs of underlying errors for grouping.
 */
@property (nonatomic, copy, readonly) NSString *identifier;

#pragma mark - Optional

@optional

/** Arbitrary description of the error.

 The maximum length is 1000 characters.
 If the value exceeds the limit, AppMetrica truncates it.
 */
@property (nonatomic, copy, readonly, nullable) NSString *message;

/** Addittional error parameters.
 Parameters are cast to key-value pairs, where key and value are strings. If the key or value differs from a string, the library automatically invokes the `description` method to create a textual representation of an object.

 The maximum number of key-value parameters is 50. The maximum length is 100 characters for the key and 2000 for the value.
 If the value exceeds the limit, AppMetrica truncates it.
 */
@property (nonatomic, copy, readonly, nullable) NSDictionary<NSString *, id> *parameters;

/** Custom error backtrace.
 You can get it from `NSThread.callStackReturnAddresses` (Objective-C) or `Thread.callStackReturnAddresses`(Swift).

 The maximum number of stack frames in a backtrace is 200.
 If the value exceeds the limit, AppMetrica truncates it.
 */
@property (nonatomic, copy, readonly, nullable) NSArray<NSNumber *> *backtrace;

/** Underlying error instance that conforms to the `AMAErrorRepresentable` protocol.

 The maximum number of underlying errors is 10.
 If the value exceeds the limit, AppMetrica truncates it.
 */
@property (nonatomic, strong, readonly, nullable) id<AMAErrorRepresentable> underlyingError;

@end

NS_ASSUME_NONNULL_END

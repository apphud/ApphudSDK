
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// `AMAAppMetricaCrashesConfiguration` provides a customizable interface for controlling how your application
/// deals with various types of crashes and issues.
///
/// This class allows you to enable or disable specific types of crash reporting and to customize the behavior
/// of the reporting mechanism.
NS_SWIFT_NAME(AppMetricaCrashesConfiguration)
@interface AMAAppMetricaCrashesConfiguration : NSObject <NSCopying>

/// Controls the automated tracking of application crashes.
///
/// If enabled, the crash reporter will automatically report application crashes.
/// - Note: This is enabled by default.
/// - To disable: Set this property to `NO`.
@property (nonatomic, assign) BOOL autoCrashTracking;

/// Controls the reporting of probably unhandled crashes like 'Out Of Memory'.
///
/// Use this to enable or disable the tracking of crashes that are probably unhandled by the application.
/// - Note: This is disabled by default.
/// - To enable: Set this property to `YES`.
@property (nonatomic, assign) BOOL probablyUnhandledCrashReporting;

/// Specifies an array of signal values to be ignored by the crash reporter.
///
/// The array should contain `NSNumber` objects configured with signal values as defined in `<sys/signal.h>`.
/// - Note: By default, no signals are ignored.
@property (nonatomic, copy, nullable) NSArray<NSNumber *> *ignoredCrashSignals;

/// Controls the detection of Application Not Responding (ANR) states.
///
/// If enabled, it will detect if the main thread is blocked and report it accordingly.
/// The detection automatically pauses when the application enters the background.
/// - Note: This is disabled by default.
/// - To enable: Set this property to `YES`.
@property (nonatomic, assign) BOOL applicationNotRespondingDetection;

/// Sets the time interval the watchdog will wait before reporting an Application Not Responding (ANR) state.
///
/// - Note: The default value is 4 seconds.
/// - Important: Takes effect only after activation and enabling `allowsBackgroundLocationUpdates`.
@property (nonatomic, assign) NSTimeInterval applicationNotRespondingWatchdogInterval;

/// Sets the frequency with which the watchdog will check for an Application Not Responding (ANR) state.
///
/// - Note: The default value is 0.1 second.
/// - Warning: Setting this to a small value can lead to poor performance.
/// - Important: Takes effect only after activation and enabling `allowsBackgroundLocationUpdates`.
@property (nonatomic, assign) NSTimeInterval applicationNotRespondingPingInterval;

@end

NS_ASSUME_NONNULL_END

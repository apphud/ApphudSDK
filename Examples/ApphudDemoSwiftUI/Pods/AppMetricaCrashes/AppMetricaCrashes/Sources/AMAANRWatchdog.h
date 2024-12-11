
#import <Foundation/Foundation.h>

@protocol AMAAsyncExecuting;
@protocol AMAANRWatchdogDelegate;

@interface AMAANRWatchdog : NSObject

@property (atomic, assign, getter = isOperating, readonly) BOOL operating;
@property (nonatomic, weak) id<AMAANRWatchdogDelegate> delegate;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithWatchdogInterval:(NSTimeInterval)watchdogInterval pingInterval:(NSTimeInterval)pingInterval;

- (instancetype)initWithWatchdogInterval:(NSTimeInterval)ANRDuration
                            pingInterval:(NSTimeInterval)checkPeriod
                        watchingExecutor:(id<AMAAsyncExecuting>)watchingExecutor
                        observedExecutor:(id<AMAAsyncExecuting>)observedExecutor NS_DESIGNATED_INITIALIZER;

- (void)start;

- (void)cancel;

@end

@protocol AMAANRWatchdogDelegate <NSObject>

- (void)ANRWatchdogDidDetectANR:(AMAANRWatchdog *)detector;

@end

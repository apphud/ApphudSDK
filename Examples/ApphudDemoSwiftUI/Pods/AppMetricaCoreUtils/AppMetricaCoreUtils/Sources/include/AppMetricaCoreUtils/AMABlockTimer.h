
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AMABlockTimer;

typedef void(^AMABlockTimerBlock)(AMABlockTimer *sender)
    NS_SWIFT_UNAVAILABLE("Use Swift closures.");

NS_SWIFT_NAME(BlockTimer)
@interface AMABlockTimer : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (id)initWithTimeout:(NSTimeInterval)timeout
                block:(AMABlockTimerBlock)block;
- (id)initWithTimeout:(NSTimeInterval)timeout
        callbackQueue:(nullable dispatch_queue_t)queue
                block:(AMABlockTimerBlock)block;

- (void)start;
- (void)invalidate;

@end

NS_ASSUME_NONNULL_END

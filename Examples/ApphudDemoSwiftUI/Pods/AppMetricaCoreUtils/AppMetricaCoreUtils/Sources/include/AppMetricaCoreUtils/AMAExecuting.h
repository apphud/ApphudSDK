
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Protocols

NS_SWIFT_NAME(AsyncExecuting)
@protocol AMAAsyncExecuting <NSObject>

- (void)execute:(dispatch_block_t)block;

@end

NS_SWIFT_NAME(SyncExecuting)
@protocol AMASyncExecuting <NSObject>
- (nullable id)syncExecute:(id _Nullable (^)(void))block;
@end


NS_SWIFT_NAME(DelayedExecuting)
@protocol AMADelayedExecuting <AMAAsyncExecuting>

- (void)executeAfterDelay:(NSTimeInterval)delay block:(dispatch_block_t)block;

@end

NS_SWIFT_NAME(CancelableExecuting)
@protocol AMACancelableExecuting <AMADelayedExecuting>

- (void)cancelDelayed;

@end

#pragma mark - AMAExecutor

NS_SWIFT_NAME(AsyncExecutor)
@interface AMAExecutor : NSObject <AMAAsyncExecuting, AMASyncExecuting>

- (instancetype)initWithQueue:(dispatch_queue_t)queue NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithIdentifier:(nullable NSObject *)identifier;

@end

#pragma mark - AMADelayedExecutor

NS_SWIFT_NAME(DelayedExecutor)
@interface AMADelayedExecutor : AMAExecutor <AMADelayedExecuting>

@end

NS_SWIFT_NAME(CancelableDelayedExecutor)
@interface AMACancelableDelayedExecutor : AMAExecutor <AMACancelableExecuting>

@end

NS_ASSUME_NONNULL_END

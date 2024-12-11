
#import <Foundation/Foundation.h>

@class AMAMultiTimer;
@protocol AMACancelableExecuting;

typedef NS_ENUM(NSInteger, AMAMultiTimerStatus) {
    AMAMultitimerStatusNotStarted,
    AMAMultitimerStatusStarted,
};

NS_ASSUME_NONNULL_BEGIN

@protocol AMAMultiTimerDelegate <NSObject>
- (void)multitimerDidFire:(AMAMultiTimer *)multitimer;
@end

@interface AMAMultiTimer : NSObject

@property (nonatomic, weak) id<AMAMultiTimerDelegate> delegate;
@property (nonatomic) AMAMultiTimerStatus status;

- (instancetype)initWithDelays:(NSArray<NSNumber *> *)delays
                      executor:(id<AMACancelableExecuting>)executor
                      delegate:(nullable id<AMAMultiTimerDelegate>)delegate;

- (void)start;
- (void)invalidate;

@end

NS_ASSUME_NONNULL_END

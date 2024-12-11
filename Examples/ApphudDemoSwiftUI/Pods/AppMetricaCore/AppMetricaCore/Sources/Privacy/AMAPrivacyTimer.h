
#import <Foundation/Foundation.h>

@class AMAPrivacyTimer;
@class AMAAdProvider;
@protocol AMACancelableExecuting;
@protocol AMAAsyncExecuting;
@protocol AMAPrivacyTimerStorage;

NS_ASSUME_NONNULL_BEGIN

@protocol AMAPrivacyTimerDelegate<NSObject>
- (void)privacyTimerDidFire:(AMAPrivacyTimer*)privacyTimer;
@end

@interface AMAPrivacyTimer : NSObject

@property (nullable, nonatomic, weak) id<AMAPrivacyTimerDelegate> delegate;
@property (nonatomic, strong) id<AMAPrivacyTimerStorage> timerStorage;

- (instancetype)initWithTimerStorage:(id<AMAPrivacyTimerStorage>)timerStorage
                    delegateExecutor:(id<AMAAsyncExecuting>)executor
                          adProvider:(AMAAdProvider*)adProvider;

- (instancetype)initWithTimerStorage:(id<AMAPrivacyTimerStorage>)timerStorage
                            executor:(id<AMACancelableExecuting>)executor
                    delegateExecutor:(id<AMAAsyncExecuting>)executor
                          adProvider:(AMAAdProvider*)adProvider;

- (void)start;
- (void)stop;

@end

NS_ASSUME_NONNULL_END

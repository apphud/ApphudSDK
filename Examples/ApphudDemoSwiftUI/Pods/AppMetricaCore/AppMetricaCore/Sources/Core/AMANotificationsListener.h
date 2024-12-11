
#import <Foundation/Foundation.h>

typedef void (^AMANotificationsListenerCallback)(NSNotification *);
@protocol AMAAsyncExecuting;

@interface AMANotificationsListener : NSObject

- (instancetype)initWithExecutor:(id<AMAAsyncExecuting>)executor;

- (void)subscribeObject:(id)object toNotification:(NSString *)notification withCallback:(AMANotificationsListenerCallback)callback;
- (void)unsubscribeObject:(id)object fromNotification:(NSString *)notification;
- (void)unsubscribeObject:(id)object;

@end


#import "AMACore.h"
#import "AMANotificationsListener.h"

@interface AMANotificationsListener ()

@property (nonatomic, strong) id<AMAAsyncExecuting> executor;
@property (nonatomic, strong) NSMapTable *objectCallbacks;
@property (nonatomic, strong) NSCountedSet *notifications;

@end

@implementation AMANotificationsListener

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (instancetype)init
{
    return [self initWithExecutor:[AMAExecutor new]];
}

- (instancetype)initWithExecutor:(id<AMAAsyncExecuting>)executor
{
    self = [super init];
    if (self) {
        _executor = executor;
        _objectCallbacks = [NSMapTable weakToStrongObjectsMapTable];
        _notifications = [NSCountedSet new];
    }
    return self;
}

#pragma mark - Public -

- (void)subscribeObject:(id)object toNotification:(NSString *)notification withCallback:(AMANotificationsListenerCallback)callback
{
    NSParameterAssert(object);
    NSParameterAssert(callback);
    NSParameterAssert(notification);
    if (object == nil || callback == nil || notification == nil) {
        return;
    }

    @synchronized (self) {
        NSMutableDictionary *notificationCallbacks = [self.objectCallbacks objectForKey:object];
        if (notificationCallbacks == nil) {
            notificationCallbacks = [NSMutableDictionary new];
            [self.objectCallbacks setObject:notificationCallbacks forKey:object];
        }

        NSMutableArray *callbacks = notificationCallbacks[notification];
        if (callbacks == nil) {
            callbacks = [NSMutableArray new];
            notificationCallbacks[notification] = callbacks;
        }

        [callbacks addObject:callback];

        NSUInteger subscribersCount = [self.notifications countForObject:notification];
        BOOL shouldSubscribeToNotification = subscribersCount == 0;
        if (shouldSubscribeToNotification) {
            [self.notifications addObject:notification];
            [[NSNotificationCenter defaultCenter] addObserver:self
                                                     selector:@selector(notificationReceived:)
                                                         name:notification
                                                       object:nil];
            AMALogInfo(@"Subscribed for notification: %@", notification);
        }
    }
}

- (void)unsubscribeObject:(id)object fromNotification:(NSString *)notification
{
    NSParameterAssert(object);
    NSParameterAssert(notification);
    if (object == nil || notification == nil) {
        return;
    }

    @synchronized (self) {
        NSMutableDictionary *notificationCallbacks = [self.objectCallbacks objectForKey:object];

        if (notificationCallbacks[notification] != nil) {
            [notificationCallbacks removeObjectForKey:notification];
            [self.notifications removeObject:notification];
        }

        NSUInteger subscribersCount = [self.notifications countForObject:notification];
        BOOL shouldUnsubscribeFromNotification = subscribersCount == 0;
        if (shouldUnsubscribeFromNotification) {
            [[NSNotificationCenter defaultCenter] removeObserver:self
                                                            name:notification
                                                          object:nil];
            AMALogInfo(@"Unsubscribed from notification: %@", notification);
        }
    }
}

- (void)unsubscribeObject:(id)object
{
    NSParameterAssert(object);
    if (object == nil) {
        return;
    }

    @synchronized (self) {
        NSDictionary *notificationCallbacks = [self.objectCallbacks objectForKey:object];
        for (NSString *notification in notificationCallbacks) {
            [self unsubscribeObject:object fromNotification:notification];
        }
        [self.objectCallbacks removeObjectForKey:object];
    }
}

#pragma mark - Private -

- (void)notificationReceived:(NSNotification *)notification
{
    if (notification.name == nil) {
        return;
    }

    @synchronized (self) {
        for (NSDictionary *notificationCallbacks in self.objectCallbacks.objectEnumerator) {
            NSArray *callbacks = [notificationCallbacks[notification.name] copy];
            if (callbacks == nil) {
                continue;
            }

            [self.executor execute:^{
                for (AMANotificationsListenerCallback callback in callbacks) {
                    callback(notification);
                }
            }];
        }
    }
}

@end

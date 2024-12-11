
#import "AMACore.h"
#import "AMAStartupItemsChangedNotifier.h"
#import "AMAStartupClientIdentifierFactory.h"
#import "AMAStartupClientIdentifier.h"
#import "AMAMetricaConfiguration.h"
#import "AMAStartupParametersConfiguration.h"
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

NSString *const kAMARequestIdentifiersOptionCallbackModeKey = @"request_mode_key";

NSString *const kAMARequestIdentifiersOptionCallbackOnSuccess = @"callback_on_success";
NSString *const kAMARequestIdentifiersOptionCallbackInAnyCase = @"callback_in_any_case";

static NSString *const kAMAObserversBlockKey = @"block_key";
static NSString *const kAMAObserversOptionsKey = @"options_key";
static NSString *const kAMAObserversQueueKey = @"queue_key";
static NSString *const kAMAObserversKeysKey = @"keys_key";

static NSString *const kAMAObserverNotificationObserverKey = @"observer_key";
static NSString *const kAMAObserverNotificationIdentifiersKey = @"identifiers_key";

typedef NSDictionary<NSString *, id> AMAIdentifierObserver;

@interface AMAStartupItemsChangedNotifier ()

@property (nonatomic, strong, readonly) NSMutableArray<AMAIdentifierObserver *> *observers;
@property (nonatomic, assign) BOOL startupLoaded;

@end

@implementation AMAStartupItemsChangedNotifier

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _observers = [NSMutableArray array];
    }
    return self;
}

#pragma mark - Public -

+ (NSArray<NSString *> *)allIdentifiersKeys
{
    return @[
        kAMAUUIDKey,
        kAMADeviceIDKey,
        kAMADeviceIDHashKey,
    ];
}

- (void)requestStartupItemsWithKeys:(NSArray<NSString *> *)keys
                            options:(NSDictionary *)options
                              queue:(dispatch_queue_t)queue
                         completion:(AMAIdentifiersCompletionBlock)block
{
    if (block != nil) {
        @synchronized(self) {
            AMAIdentifierObserver *item = [self observerItemWithKeys:keys options:options block:block queue:queue];
            if (item != nil) {
                [self.observers addObject:item];
            }
        }
    }
    
    [self notifyOnIdentifiersChanged];
}

#pragma mark - Private -

- (AMAIdentifierObserver *)observerItemWithKeys:(NSArray *)keys
                                        options:(NSDictionary *)options
                                          block:(AMAIdentifiersCompletionBlock)block
                                          queue:(dispatch_queue_t)queue
{
    NSMutableDictionary *item = [NSMutableDictionary dictionary];
    item[kAMAObserversKeysKey] = [keys copy];
    item[kAMAObserversOptionsKey] = [options copy];
    item[kAMAObserversBlockKey] = [block copy];
    item[kAMAObserversQueueKey] = queue;
    return [item copy];
}

- (void)notifyOnIdentifiersChanged
{
    NSMutableArray *observerNotifications = [NSMutableArray array];
    @synchronized (self) {
        NSDictionary *availableFields = self.availableStartupItems;
        [AMACollectionUtilities removeItemsFromArray:self.observers
                                           withBlock:^(AMAIdentifierObserver *observer, BOOL *remove) {
            NSDictionary *identifiers = [self filteredItemsForObserver:observer withAllItems:availableFields];
            if (identifiers != nil) {
                [observerNotifications addObject:@{
                    kAMAObserverNotificationObserverKey: observer,
                    kAMAObserverNotificationIdentifiersKey: identifiers,
                }];
                *remove = YES;
            }
        }];
    }
    
    for (NSDictionary *observerNotification in observerNotifications) {
        AMAIdentifierObserver *observer = observerNotification[kAMAObserverNotificationObserverKey];
        NSDictionary *identifiers = observerNotification[kAMAObserverNotificationIdentifiersKey];
        AMALogInfo(@"Notifying identifiers: %@", identifiers);
        [self notifyObserver:observer withIdentifiers:identifiers error:nil];
    }
}

- (NSDictionary *)availableStartupItems
{
    NSMutableDictionary *availableFields = [NSMutableDictionary dictionary];
    AMAStartupClientIdentifier *startupClientIdentifier = AMAStartupClientIdentifierFactory.startupClientIdentifier;
    AMAStartupParametersConfiguration *startup = [AMAMetricaConfiguration sharedInstance].startup;
    
    availableFields[kAMAUUIDKey] = startupClientIdentifier.UUID;
    availableFields[kAMADeviceIDHashKey] = startupClientIdentifier.deviceIDHash;
    
    if (startupClientIdentifier.deviceID.length != 0) {
        availableFields[kAMADeviceIDKey] = startupClientIdentifier.deviceID;
    }
    if (startup.SDKsCustomHosts != nil) {
        [availableFields addEntriesFromDictionary:startup.SDKsCustomHosts];
    }
    
    if (startup.extendedParameters != nil) {
        [availableFields addEntriesFromDictionary:startup.extendedParameters];
    }
    
    return [availableFields copy];
}

- (NSDictionary *)filteredItemsForObserver:(AMAIdentifierObserver *)observer withAllItems:(NSDictionary *)allItems
{
    NSSet *requiredKeys = [NSSet setWithArray:observer[kAMAObserversKeysKey]];
    NSDictionary *items = [AMACollectionUtilities filteredDictionary:allItems withKeys:requiredKeys];
    if (items.count != requiredKeys.count && self.startupLoaded == NO) {
        AMALogInfo(@"Not all keys for observer are ready. Waiting for startup.");
        items = nil;
    }
    return items;
}

- (void)notifyObserver:(AMAIdentifierObserver *)observer
       withIdentifiers:(NSDictionary *)identifiers
                 error:(NSError *)error
{
    AMAIdentifiersCompletionBlock block = observer[kAMAObserversBlockKey];
    dispatch_queue_t queue = observer[kAMAObserversQueueKey];
    if (queue == nil) {
        queue = dispatch_get_main_queue();
    }
    [self dispatchBlock:block withAvailableFields:identifiers toQueue:queue error:error];
}

- (void)dispatchBlock:(AMAIdentifiersCompletionBlock)block
  withAvailableFields:(NSDictionary *)availableFields
              toQueue:(dispatch_queue_t)queue
                error:(NSError *)error
{
    dispatch_block_t dispatchBlock = ^{
        block(availableFields, error);
    };
    dispatch_async(queue, dispatchBlock);
}

#pragma mark - AMAStartupCompletionObserving

- (void)startupUpdateCompletedWithConfiguration:(AMAStartupParametersConfiguration *)configuration
{
    @synchronized (self) {
        self.startupLoaded = YES;
    }
    [self notifyOnIdentifiersChanged];
}

- (void)startupUpdateFailedWithError:(NSError *)error
{
    NSMutableArray *observersToNotifyError = [NSMutableArray array];
    @synchronized (self) {
        if (self.startupLoaded == YES) {
            return;
        }
        [AMACollectionUtilities removeItemsFromArray:self.observers
                                           withBlock:^(AMAIdentifierObserver *observer, BOOL *remove) {
            NSString *callbackMode = observer[kAMAObserversOptionsKey][kAMARequestIdentifiersOptionCallbackModeKey];
            if ([callbackMode isEqualToString:kAMARequestIdentifiersOptionCallbackInAnyCase]) {
                [observersToNotifyError addObject:observer];
                *remove = YES;
            }
        }];
    }
    
    for (AMAIdentifierObserver *observer in observersToNotifyError) {
        [self notifyObserver:observer withIdentifiers:nil error:error];
    }
}

@end

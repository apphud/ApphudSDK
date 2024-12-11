
#import "AMACore.h"
#import "AMAEnvironmentLimiter.h"

@interface AMAEnvironmentContainer ()

@property (nonatomic, strong) AMAEnvironmentLimiter *limiter;
@property (atomic, copy) NSDictionary *environment;
@property (nonatomic, strong) NSMapTable *observers;
@property (nonatomic, assign) BOOL isNotificationAvailable;

@end

@implementation AMAEnvironmentContainer

- (instancetype)init
{
    return [self initWithDictionaryEnvironment:nil];
}

- (instancetype)initWithDictionaryEnvironment:(nullable NSDictionary *)dictionaryEnvironment
{
    return [self initWithDictionaryEnvironment:dictionaryEnvironment
                                       limiter:[AMAEnvironmentLimiter new]];
}

- (instancetype)initWithDictionaryEnvironment:(nullable NSDictionary *)dictionaryEnvironment
                                      limiter:(AMAEnvironmentLimiter *)limiter
{
    self = [super init];
    if (self) {
        _environment = dictionaryEnvironment ? [dictionaryEnvironment copy] : @{};
        _limiter = limiter;
        _observers = [[NSMapTable alloc] initWithKeyOptions:NSPointerFunctionsWeakMemory
                                               valueOptions:NSPointerFunctionsStrongMemory
                                                   capacity:0];
        _isNotificationAvailable = YES;
    }

    return self;
}

#pragma mark - Environment Handling

- (void)addValue:(nullable NSString *)value forKey:(NSString *)key
{
    if (key.length == 0) {
        return;
    }

    BOOL shouldNotifyObservers = YES;

    @synchronized (self) {
        if (value == nil) {
            NSMutableDictionary *updatedEnvironment = [(self.environment ?: @{}) mutableCopy];
            [updatedEnvironment removeObjectForKey:key];
            self.environment = updatedEnvironment;
        }
        else {
            self.environment = [self.limiter limitEnvironment:self.environment afterAddingValue:value forKey:key];
        }

        shouldNotifyObservers = self.isNotificationAvailable;
    }

    if (shouldNotifyObservers) {
        [self notifyObserversEnvironmentDidChange];
    }
}

- (void)clearEnvironment
{
    BOOL shouldNotifyObservers = YES;

    @synchronized (self) {
        if (self.environment.count == 0) {
            return;
        }
        self.environment = @{};

        shouldNotifyObservers = self.isNotificationAvailable;
    }

    if (shouldNotifyObservers) {
        [self notifyObserversEnvironmentDidChange];
    }
}

- (NSDictionary *)dictionaryEnvironment
{
    return self.environment;
}

- (void)performBatchUpdates:(AMAEnvironmentContainerUpdatesBlock)updatesBlock
{
    BOOL shouldNotifyObservers = NO;

    @synchronized (self) {
        self.isNotificationAvailable = NO;

        NSDictionary *beforeUpdateEnvironment = self.environment;
        if (updatesBlock != nil) {
            updatesBlock();
        }
        NSDictionary *afterUpdateEnvironment = self.environment;

        shouldNotifyObservers = [beforeUpdateEnvironment isEqual:afterUpdateEnvironment] == NO;

        self.isNotificationAvailable = YES;
    }

    if (shouldNotifyObservers) {
        [self notifyObserversEnvironmentDidChange];
    }
}

#pragma mark - Observing

- (void)notifyObserversEnvironmentDidChange
{
    NSMapTable *observers;
    @synchronized (self.observers) {
        observers = [self.observers copy];
    }

    for (id observer in observers) {
        AMAEnvironmentContainerDidChangeBlock block = [observers objectForKey:observer];
        block(observer, self);
    }
}

- (void)addObserver:(id)observer withBlock:(AMAEnvironmentContainerDidChangeBlock)block
{
    if (observer == nil || block == nil) {
        return;
    }

    @synchronized (self.observers) {
        [self.observers setObject:block forKey:observer];
    }
}

- (void)removeObserver:(id)observer
{
    if (observer == nil) {
        return;
    }

    @synchronized (self.observers) {
        [self.observers removeObjectForKey:observer];
    }
}

@end

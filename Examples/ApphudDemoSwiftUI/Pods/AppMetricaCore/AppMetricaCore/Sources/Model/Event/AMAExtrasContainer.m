#import "AMAExtrasContainer.h"

@interface AMAExtrasContainer ()
@property (nonnull, nonatomic, strong) NSMapTable *observers;

@end

@implementation AMAExtrasContainer
@synthesize dictionaryExtras = _dictionaryExtras;

- (instancetype)init
{
    return [self initWithDictionaryExtras:nil];
}

- (instancetype)initWithDictionaryExtras:(nullable NSDictionary<NSString *, NSData *> *)dictionaryExtras
{
    self = [super init];
    if (self != nil) {
        _dictionaryExtras = dictionaryExtras ?: [NSDictionary dictionary];
        _observers = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsWeakMemory valueOptions:NSPointerFunctionsStrongMemory];
    }
    return self;
}

- (void)addValue:(nullable NSData *)value forKey:(NSString *)key
{
    NSData *val = value ?: [NSData data];
    @synchronized (self) {
        NSMutableDictionary *updated = [_dictionaryExtras mutableCopy];
        updated[key] = val;
        _dictionaryExtras = [updated copy];
    }

    [self notifyObserversExtrasDidChange];
}

- (void)removeValueForKey:(NSString *)key
{
    @synchronized (self) {
        NSMutableDictionary *updated = [_dictionaryExtras mutableCopy];
        updated[key] = nil;
        _dictionaryExtras = [updated copy];
    }

    [self notifyObserversExtrasDidChange];
}

- (void)clearExtras
{
    @synchronized (self) {
        _dictionaryExtras = [NSDictionary dictionary];
    }

    [self notifyObserversExtrasDidChange];
}

- (NSDictionary<NSString *, NSData *> *)dictionaryExtras
{
    NSDictionary<NSString *, NSData *> *result = nil;
    @synchronized (self) {
        result = _dictionaryExtras;
    }
    return result;
}

- (void)notifyObserversExtrasDidChange
{
    NSMapTable *observers = nil;
    @synchronized (self.observers) {
        observers = [self.observers copy];
    }

    for (id observer in observers) {
        AMAExtrasContainerDidChangeBlock block = [observers objectForKey:observer];
        block(observer, self);
    }
}

- (void)addObserver:(id)observer withBlock:(AMAExtrasContainerDidChangeBlock)block
{
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

+ (instancetype)container
{
    return [[self alloc] init];
}
+ (instancetype)containerWithDictionary:(nullable NSDictionary<NSString *, NSData *> *)dictionaryExtras
{
    return [[self alloc] initWithDictionaryExtras:dictionaryExtras];
}

@end

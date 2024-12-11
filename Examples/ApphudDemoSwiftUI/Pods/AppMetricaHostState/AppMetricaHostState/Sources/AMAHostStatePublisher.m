
#import "AMAHostStatePublisher.h"
#import "AMAHostStateControlling.h"

@interface AMAHostStatePublisher ()

@property (nonatomic, strong) NSHashTable *observersTable;

@end

@implementation AMAHostStatePublisher


- (instancetype)init
{
    self = [super init];
    if (self) {
        _observersTable = [NSHashTable weakObjectsHashTable];
    }

    return self;
}

- (void)hostStateDidChange
{
    NSHashTable *observers;
    @synchronized (self.observersTable) {
        observers = [self.observersTable copy];
    }
    
    for (id<AMAHostStateProviderObserver> observer in observers) {
        [observer hostStateProviderDidChangeHostState];
    }
}

#pragma mark - AMABroadcating

- (NSArray *)observers
{
    @synchronized (self.observersTable) {
        return self.observersTable.allObjects;
    }
}

- (void)addAMAObserver:(id<AMAHostStateProviderObserver>)observer
{
    @synchronized (self.observersTable) {
        [self.observersTable addObject:observer];
    }
}

- (void)removeAMAObserver:(id<AMAHostStateProviderObserver>)observer
{
    @synchronized (self.observersTable) {
        [self.observersTable removeObject:observer];
    }
}

@end

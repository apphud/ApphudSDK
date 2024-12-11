
#import "AMADispatchStrategiesContainer.h"
#import "AMATimerDispatchStrategy.h"
#import "AMAReporterStorage.h"

@interface AMADispatchStrategiesContainer() {
@private
    NSMutableSet *_dispatchStrategies;
}

@end

@implementation AMADispatchStrategiesContainer

- (id)init
{
    self = [super init];
    if (self) {
        _dispatchStrategies = [NSMutableSet set];
    }
    return self;
}

- (NSSet *)strategies
{
    @synchronized(self) {
        return [_dispatchStrategies copy];
    }
}

- (void)addStrategies:(NSArray *)strategies
{
    @synchronized(self) {
        if (strategies != nil) {
            [_dispatchStrategies addObjectsFromArray:strategies];
        }
    }
}

- (void)startStrategies:(NSArray *)strategies;
{
    [strategies makeObjectsPerformSelector:@selector(restart)];
}

- (void)dispatchMoreIfNeeded
{
    [[self strategies] makeObjectsPerformSelector:@selector(restart)];
}

- (void)dispatchMoreIfNeededForApiKey:(NSString *)apiKey
{
    for (AMADispatchStrategy *strategy in self.strategies) {
        if ([strategy.storage.apiKey isEqual:apiKey]) {
            [strategy restart];
        }
    }
}

- (void)shutdown
{
    [[self strategies] makeObjectsPerformSelector:@selector(shutdown)];
}

- (void)handleConfigurationUpdate
{
    [[self strategies] makeObjectsPerformSelector:@selector(restart)];
}

@end

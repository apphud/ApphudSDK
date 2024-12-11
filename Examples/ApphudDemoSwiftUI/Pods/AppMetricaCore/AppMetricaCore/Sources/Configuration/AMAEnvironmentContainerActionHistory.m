
#import "AMAEnvironmentContainerActionHistory.h"
#import "AMAEnvironmentContainerAction.h"

@interface AMAEnvironmentContainerActionHistory ()

@property (nonatomic, strong) NSMutableArray *actions;

@end

@implementation AMAEnvironmentContainerActionHistory

- (instancetype)init
{
    self = [super init];
    if (self) {
        _actions = [NSMutableArray new];
    }

    return self;
}

- (void)trackAddValue:(NSString *)value forKey:(NSString *)key
{
    @synchronized (self.actions) {
        id<AMAEnvironmentContainerAction> action =
                [[AMAEnvironmentContainerAddValueAction alloc] initWithValue:value forKey:key];
        if (action != nil) {
            [self.actions addObject:action];
        }
    }
}

- (void)trackClearEnvironment
{
    @synchronized (self.actions) {
        id<AMAEnvironmentContainerAction> action = [AMAEnvironmentContainerClearAction new];
        if (action != nil) {
            [self.actions addObject:action];
        }
    }
}

- (NSArray *)trackedActions
{
    @synchronized (self.actions) {
        return [self.actions copy];
    }
}

@end

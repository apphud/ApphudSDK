
#import "AMACore.h"
#import "AMAStartupHostProvider.h"
#import "AMAMetricaConfiguration.h"
#import "AMAStartupParametersConfiguration.h"
#import "AMAMetricaPersistentConfiguration.h"
#import "AMAMetricaInMemoryConfiguration.h"
#import "AMADefaultStartupHostsProvider.h"

@interface AMAStartupHostProvider ()

@property (nonatomic, strong) AMAArrayIterator *iterator;

@end

@implementation AMAStartupHostProvider

+ (NSArray *)startupHosts
{
    return [AMAMetricaConfiguration sharedInstance].startup.startupHosts;
}

+ (NSArray *)userStartupHosts
{
    return [AMAMetricaConfiguration sharedInstance].persistent.userStartupHosts;
}

+ (NSArray *)additionalStartupHosts
{
    return [[AMAMetricaConfiguration sharedInstance].inMemory additionalStartupHosts];
}

- (id)current
{
    return [self.iterator current];
}

- (id)next
{
    return [self.iterator next];
}

- (void)reset
{
    NSMutableOrderedSet *hosts = [NSMutableOrderedSet new];

    NSArray *array = [[self class] startupHosts];
    if (array != nil) {
        [hosts addObjectsFromArray:array];
    }
    
    array = [[self class] userStartupHosts];
    if (array != nil) {
        [hosts addObjectsFromArray:array];
    }
    
    NSArray *additionalHosts = [[self class] additionalStartupHosts];
    [hosts addObjectsFromArray:[AMADefaultStartupHostsProvider startupHostsWithAdditionalHosts:additionalHosts]];
    
    self.iterator = [[AMAArrayIterator alloc] initWithArray:[hosts array]];
}

@end

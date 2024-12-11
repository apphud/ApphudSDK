
#import "AMATrackingHostProvider.h"
#import "AMAMetricaConfiguration.h"
#import "AMAStartupParametersConfiguration.h"

@interface AMATrackingHostProvider ()

@property (nonatomic, strong) AMAArrayIterator *iterator;

@end

@implementation AMATrackingHostProvider

+ (NSArray *)trackingHosts
{
    return [AMAMetricaConfiguration sharedInstance].startup.appleTrackingHosts;
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
    self.iterator = [[AMAArrayIterator alloc] initWithArray:[[self class] trackingHosts]];
}

@end

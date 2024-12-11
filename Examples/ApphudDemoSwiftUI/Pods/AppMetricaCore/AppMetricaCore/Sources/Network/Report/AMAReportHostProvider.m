
#import "AMAReportHostProvider.h"
#import "AMAMetricaConfiguration.h"
#import "AMAStartupParametersConfiguration.h"

@interface AMAReportHostProvider ()

@property (nonatomic, strong) AMAArrayIterator *iterator;

@end

@implementation AMAReportHostProvider

+ (NSArray *)reportHosts
{
    return [AMAMetricaConfiguration sharedInstance].startup.reportHosts;
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
    self.iterator = [[AMAArrayIterator alloc] initWithArray:[[self class] reportHosts]];
}

@end

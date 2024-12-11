
#import "AMACrashReportCrash.h"

@implementation AMACrashReportCrash

- (instancetype)initWithError:(AMACrashReportError *)error threads:(NSArray<AMAThread *> *)threads
{
    self = [super init];
    if (self != nil) {
        _error = error;
        _threads = [threads copy];
    }

    return self;
}

#pragma mark - NSCopying

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] alloc] initWithError:self.error
                                       threads:[[NSArray alloc] initWithArray:self.threads copyItems:YES]];
}

@end

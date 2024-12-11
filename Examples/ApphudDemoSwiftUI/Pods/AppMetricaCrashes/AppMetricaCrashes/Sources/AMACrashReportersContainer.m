
#import "AMACrashReportersContainer.h"
#import "AMAAppMetricaCrashReporting.h"

@interface AMACrashReportersContainer ()

@property (nonatomic, strong) NSMutableDictionary *reporters;

@end

@implementation AMACrashReportersContainer

- (id)init
{
    self = [super init];
    if (self) {
        _reporters = [NSMutableDictionary new];
    }
    return self;
}

- (id<AMAAppMetricaCrashReporting>)reporterForAPIKey:(NSString *)apiKey
{
    if (apiKey == nil) {
        return nil;
    }
    
    @synchronized(self) {
        id<AMAAppMetricaCrashReporting> reporter = self.reporters[apiKey];
        return reporter;
    }
}

- (void)setReporter:(id<AMAAppMetricaCrashReporting>)reporter forAPIKey:(NSString *)apiKey
{
    if (reporter == nil || apiKey == nil) {
        return;
    }

    @synchronized(self) {
        self.reporters[apiKey] = reporter;
    }
}

@end

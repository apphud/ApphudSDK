
#import "AMACore.h"
#import "AMAReportersContainer.h"
#import "AMAReporter.h"
#import "AMAStartupController.h"

@interface AMAReportersContainer ()

@property (nonatomic, strong) NSMutableDictionary *reporters;

@end

@implementation AMAReportersContainer

- (id)init
{
    self = [super init];
    if (self) {
        _reporters = [NSMutableDictionary new];
    }
    return self;
}

- (AMAReporter *)reporterForApiKey:(NSString *)apiKey
{
    if (apiKey == nil) {
        return nil;
    }
    
    @synchronized(self) {
        AMAReporter *reporter = self.reporters[apiKey];
        return reporter;
    }
}

- (void)setReporter:(AMAReporter *)reporter forApiKey:(NSString *)apiKey
{
    if (reporter == nil || apiKey == nil) {
        return;
    }

    @synchronized(self) {
        self.reporters[apiKey] = reporter;
    }
}

- (void)restartPrivacyTimer
{
    NSDictionary *reporters = nil;
    @synchronized (self) {
        reporters = [self.reporters copy];
    }
    for (AMAReporter *reporter in reporters.objectEnumerator) {
        [reporter restartPrivacyTimer];
    }
}

@end

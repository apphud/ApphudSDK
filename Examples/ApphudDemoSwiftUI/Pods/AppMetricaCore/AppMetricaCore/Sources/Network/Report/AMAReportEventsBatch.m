
#import "AMAReportEventsBatch.h"

@implementation AMAReportEventsBatch

- (instancetype)initWithSession:(AMASession *)session
                 appEnvironment:(NSDictionary *)appEnvironment
                         events:(NSArray<AMAEvent *> *)events
{
    self = [super init];
    if (self != nil) {
        _session = session;
        _appEnvironment = [appEnvironment copy];
        _events = [events copy];
    }
    return self;
}

#if AMA_ALLOW_DESCRIPTIONS
- (NSString *)description
{
    NSString *superDescription = [super description];
    NSString *format = @"%@\nSession: %@\nAppEnvironment: %@\nEvents: %@";
    NSString *description = [NSString stringWithFormat:format, superDescription,
                             self.session, self.appEnvironment, self.events];
    return description;
}
#endif

@end

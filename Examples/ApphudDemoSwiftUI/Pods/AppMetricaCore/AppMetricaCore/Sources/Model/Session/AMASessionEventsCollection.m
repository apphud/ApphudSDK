
#import "AMASessionEventsCollection.h"

@implementation AMASessionEventsCollection

- (instancetype)initWithSession:(AMASession *)session events:(NSArray<AMAEvent *> *)events
{
    self = [super init];
    if (self != nil) {
        _session = session;
        _events = [events copy];
    }
    return self;
}

@end

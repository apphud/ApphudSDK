
#import "AMACore.h"

@implementation AMAEventPollingParameters

- (instancetype)initWithEventType:(NSUInteger)eventType
{
    self = [super init];
    if (self != nil) {
        _eventType = eventType;
        _fileName = nil;
        _appEnvironment = self.appEnvironment.copy;
        _eventEnvironment = self.eventEnvironment.copy;
        _extras = self.extras.copy;
        _bytesTruncated = 0;
    }
    return self;
}

@end

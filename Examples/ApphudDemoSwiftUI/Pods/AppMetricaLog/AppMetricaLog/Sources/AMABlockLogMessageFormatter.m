
#import "AMABlockLogMessageFormatter.h"

@interface AMABlockLogMessageFormatter ()

@property (nonatomic, copy) AMABlockLogMessageFormatterCallback formatCallback;

@end

@implementation AMABlockLogMessageFormatter

+ (instancetype)formatterWithBlock:(AMABlockLogMessageFormatterCallback)formatCallback
{
    return [[self alloc] initWithFormatterBlock:formatCallback];
}

- (instancetype)initWithFormatterBlock:(AMABlockLogMessageFormatterCallback)formatCallback
{
    NSParameterAssert(formatCallback);
    if (formatCallback == nil) {
        return nil;
    }

    self = [super init];
    if (self) {
        _formatCallback = [formatCallback copy];
    }

    return self;
}

- (NSString *)messageToString:(AMALogMessage *)message
{
    if (message == nil) {
        return nil;
    }

    NSString *string = self.formatCallback(message);
    return string;
}

@end

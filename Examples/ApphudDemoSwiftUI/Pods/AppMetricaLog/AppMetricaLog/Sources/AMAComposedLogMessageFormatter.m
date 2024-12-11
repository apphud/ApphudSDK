
#import "AMAComposedLogMessageFormatter.h"

@interface AMAComposedLogMessageFormatter ()

@property (nonatomic, copy) NSArray *formatters;

@end

@implementation AMAComposedLogMessageFormatter

- (instancetype)initWithFormatters:(NSArray *)formatters
{
    self = [super init];
    if (self) {
        _formatters = [formatters copy];
    }

    return self;
}

- (NSString *)messageToString:(AMALogMessage *)message
{
    if (message == nil) {
        return nil;
    }

    NSMutableString *composedMessage = [NSMutableString new];
    for (id<AMALogMessageFormatting> formatter in self.formatters) {
        NSString *stringMessage = [formatter messageToString:message];
        if (stringMessage.length == 0) {
            continue;
        }

        if (composedMessage.length != 0) {
            [composedMessage appendString:@" "];
        }
        [composedMessage appendString:stringMessage];
    }

    return composedMessage;
}

@end

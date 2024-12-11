
#import "AMALogMessageFormatterFactory.h"
#import "AMALogMessageFormatting.h"
#import "AMAComposedLogMessageFormatter.h"
#import "AMALogMessage.h"
#import "AMADateLogMessageFormatter.h"
#import "AMABlockLogMessageFormatter.h"

@interface AMALogMessageFormatterFactory ()

@property (nonatomic, copy) NSDictionary *formatters;

@end

@implementation AMALogMessageFormatterFactory

+ (NSDictionary *)defaultFormatters
{
    return @{
            @(AMALogFormatPartDate) : [AMADateLogMessageFormatter new],
            @(AMALogFormatPartOrigin) : [AMABlockLogMessageFormatter formatterWithBlock:^(AMALogMessage *message){
                return [NSString stringWithFormat:@"%@:%lu", message.function, (unsigned long)message.line];
            }],
            @(AMALogFormatPartContent) : [AMABlockLogMessageFormatter formatterWithBlock:^(AMALogMessage *message){
                return message.content;
            }],
            @(AMALogFormatPartBacktrace) : [AMABlockLogMessageFormatter formatterWithBlock:^(AMALogMessage *message){
                return message.backtrace != nil ? [NSString stringWithFormat:@"\nBacktrace:\n%@", message.backtrace] : nil;
            }],
            @(AMALogFormatPartPublicPrefix) : [AMABlockLogMessageFormatter formatterWithBlock:^(AMALogMessage *message){
                return @"AppMetrica:";
            }],
    };
}

- (instancetype)init
{
    return [self initWithFormatters:[self.class defaultFormatters]];
}

- (instancetype)initWithFormatters:(NSDictionary *)formatters
{
    self = [super init];
    if (self) {
        _formatters = [formatters copy];
    }

    return self;
}

- (id<AMALogMessageFormatting>)formatterWithFormatParts:(NSArray *)format
{
    NSMutableArray *formatters = [NSMutableArray new];
    for (id part in format) {
        id<AMALogMessageFormatting> formatter = self.formatters[part];
        NSAssert(formatter, @"Failed to get formatter for part %@", part);
        if (formatter != nil) {
            [formatters addObject:formatter];
        }
    }

    if (formatters.count == 0) {
        return nil;
    }

    AMAComposedLogMessageFormatter *formatter = [[AMAComposedLogMessageFormatter alloc] initWithFormatters:formatters];
    return formatter;
}

@end


#import "AMALogMessageFactory.h"
#import "AMALogMessage.h"

static NSUInteger const kAMANumberOfLogMethodsInBacktrace = 4;
static NSUInteger const kAMABacktraceMaxRows = kAMANumberOfLogMethodsInBacktrace + 5;

@implementation AMALogMessageFactory

- (AMALogMessage *)messageWithLevel:(AMALogLevel)level
                            channel:(AMALogChannel)channel
                               file:(char const *)file
                           function:(char const *)function
                               line:(NSUInteger)line
                       addBacktrace:(BOOL)addBacktrace
                             format:(NSString *)format
                               args:(va_list)args
{
    NSString *content = [[NSString alloc] initWithFormat:format arguments:args];
    NSString *fileString = [[NSString stringWithCString:file encoding:NSUTF8StringEncoding] lastPathComponent];
    NSString *functionString = [NSString stringWithCString:function encoding:NSUTF8StringEncoding];
    NSDate *timestamp = [NSDate date];
    NSString *backtrace = addBacktrace ? [self backtrace] : nil;

    AMALogMessage *message = [[AMALogMessage alloc] initWithContent:content
                                                              level:level
                                                            channel:channel
                                                               file:fileString
                                                           function:functionString
                                                               line:line
                                                          backtrace:backtrace
                                                          timestamp:timestamp];
    return message;
}

- (NSString *)backtrace
{
    NSString *backtrace = nil;
    NSArray *symbols = [NSThread callStackSymbols];
    if (symbols.count > kAMANumberOfLogMethodsInBacktrace) {
        NSRange range = NSMakeRange(kAMANumberOfLogMethodsInBacktrace,
                                    MIN(kAMABacktraceMaxRows, symbols.count) - kAMANumberOfLogMethodsInBacktrace);
        NSArray *rows = [symbols subarrayWithRange:range];
        if (symbols.count > kAMABacktraceMaxRows) {
            NSString *skippedRowsDescription =
                [NSString stringWithFormat:@"(skipped %lu rows)", (unsigned long)(symbols.count - kAMABacktraceMaxRows)];
            rows = [rows arrayByAddingObject:skippedRowsDescription];
        }
        backtrace = [rows componentsJoinedByString:@"\n"];
    }
    return backtrace;
}

@end

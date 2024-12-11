
#import "AMALogMessage.h"

@interface AMALogMessage ()

@property (nonatomic, copy, readwrite) NSString *content;
@property (nonatomic, assign, readwrite) AMALogLevel level;
@property (nonatomic, copy, readwrite) AMALogChannel channel;
@property (nonatomic, copy, readwrite) NSString *file;
@property (nonatomic, copy, readwrite) NSString *function;
@property (nonatomic, assign, readwrite) NSUInteger line;
@property (nonatomic, strong, readwrite) NSDate *timestamp;

@end

@implementation AMALogMessage

- (instancetype)initWithContent:(NSString *)content
                          level:(AMALogLevel)level
                        channel:(AMALogChannel)channel
                           file:(NSString *)file
                       function:(NSString *)function
                           line:(NSUInteger)line
                      backtrace:(NSString *)backtrace
                      timestamp:(NSDate *)timestamp
{
    self = [super init];
    if (self) {
        _content = [content copy];
        _level = level;
        _channel = [channel copy];
        _file = [file copy];
        _function = [function copy];
        _line = line;
        _backtrace = [backtrace copy];
        _timestamp = timestamp;
    }

    return self;
}

@end


#import <AppMetricaLog/AppMetricaLog.h>

@interface AMALogMessage : NSObject

@property (nonatomic, copy, readonly) NSString *content;

@property (nonatomic, assign, readonly) AMALogLevel level;
@property (nonatomic, copy, readonly) AMALogChannel channel;

@property (nonatomic, copy, readonly) NSString *file;
@property (nonatomic, copy, readonly) NSString *function;
@property (nonatomic, assign, readonly) NSUInteger line;
@property (nonatomic, copy, readonly) NSString *backtrace;

@property (nonatomic, strong, readonly) NSDate *timestamp;

- (instancetype)initWithContent:(NSString *)content
                          level:(AMALogLevel)level
                        channel:(AMALogChannel)channel
                           file:(NSString *)file
                       function:(NSString *)function
                           line:(NSUInteger)line
                      backtrace:(NSString *)backtrace
                      timestamp:(NSDate *)timestamp;

@end


#import "AMALogMessageFactory.h"
#import "AMALogOutput.h"

static const char *kAMALogQueue = "io.appmetrica.log";

@interface AMALogFacade ()

@property (nonatomic, strong) AMALogMessageFactory *messageFactory;
@property (nonatomic, strong) dispatch_queue_t asyncLogQueue;
@property (atomic, strong) NSSet *outputs;

@end

@implementation AMALogFacade

+ (instancetype)sharedLog
{
    static AMALogFacade *sharedLog = nil;
    static dispatch_once_t token;
    dispatch_once(&token, ^{
        sharedLog = [AMALogFacade new];
    });
    return sharedLog;
}

- (instancetype)initWithAsyncLogQueue:(dispatch_queue_t)queue
{
    self = [super init];
    if (self) {
        _messageFactory = [AMALogMessageFactory new];
        _asyncLogQueue = queue;
        _outputs = [NSSet set];
    }

    return self;
}

- (instancetype)init
{
    dispatch_queue_t queue = dispatch_queue_create(kAMALogQueue, DISPATCH_QUEUE_SERIAL);
    return [self initWithAsyncLogQueue:queue];
}

- (void)logMessageToChannel:(AMALogChannel)channel
                      level:(AMALogLevel)level
                       file:(const char *)file
                   function:(const char *)function
                       line:(NSUInteger)line
               addBacktrace:(BOOL)addBacktrace
                     format:(NSString *)format, ...
{
    if (format == nil) {
        return;
    }

    va_list args;
    va_start(args, format);
    [self logMessageToChannel:channel
                        level:level
                         file:file
                     function:function
                         line:line
                 addBacktrace:addBacktrace
                       format:format
                         args:args];
    va_end(args);
}

- (void)logMessageToChannel:(AMALogChannel)channel
                      level:(AMALogLevel)level
                       file:(const char *)file
                   function:(const char *)function
                       line:(NSUInteger)line
               addBacktrace:(BOOL)addBacktrace
                     format:(NSString *)format
                       args:(va_list)args
{
    NSMutableArray *outputs = [NSMutableArray new];
    for (AMALogOutput *output in self.outputs) {
        if ([output canLogToChannel:channel withLevel:level]) {
            [outputs addObject:output];
        }
    }

    if (outputs.count == 0) {
        return;
    }

    AMALogMessage *message = [self.messageFactory messageWithLevel:level
                                                           channel:channel
                                                              file:file
                                                          function:function
                                                              line:line
                                                      addBacktrace:addBacktrace
                                                            format:format
                                                              args:args];

    BOOL isAsyncMiddlewarePresented = NO;
    for (AMALogOutput *output in outputs) {
        if (output.isAsyncLoggingAcceptable) {
            isAsyncMiddlewarePresented = YES;
        } else {
            [output logMessage:message];
        }
    }

    if (isAsyncMiddlewarePresented == NO) {
        return;
    }

    dispatch_async(self.asyncLogQueue, ^{
        for (AMALogOutput *output in outputs) {
            if (output.isAsyncLoggingAcceptable) {
                [output logMessage:message];
            }
        }
    });
}

- (void)addOutput:(AMALogOutput *)output
{
    @synchronized (self) {
        NSMutableSet *outputs = [NSMutableSet setWithSet:self.outputs];
        [outputs addObject:output];
        self.outputs = outputs;
    }
}

- (void)removeOutput:(AMALogOutput *)output
{
    @synchronized (self) {
        NSMutableSet *outputs = [NSMutableSet setWithSet:self.outputs];
        [outputs removeObject:output];
        self.outputs = outputs;
    }
}

- (NSArray *)outputsWithChannel:(AMALogChannel)channel
{
    @synchronized (self) {
        NSMutableArray *outputs = [NSMutableArray new];
        for (AMALogOutput *output in self.outputs) {
            if ([output isMatchingChannel:channel]) {
                [outputs addObject:output];
            }
        }
        return outputs;
    }
}

@end

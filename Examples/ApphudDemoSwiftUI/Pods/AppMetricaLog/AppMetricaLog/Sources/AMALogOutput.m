
#import "AMALogOutput.h"
#import "AMALogMiddleware.h"
#import "AMALogMessageFormatting.h"
#import "AMALogMessage.h"

@interface AMALogOutput ()

@property (nonatomic, copy) AMALogChannel channel;
@property (nonatomic, assign) AMALogLevel logLevel;
@property (nonatomic, strong) id<AMALogMessageFormatting> formatter;
@property (nonatomic, strong) id<AMALogMiddleware> middleware;

@end

@implementation AMALogOutput

- (instancetype)initWithChannel:(AMALogChannel)channel
                          level:(AMALogLevel)level
                      formatter:(id<AMALogMessageFormatting>)formatter
                     middleware:(id<AMALogMiddleware>)middleware
{
    self = [super init];
    if (self) {
        _channel = [channel copy];
        _logLevel = level;
        _formatter = formatter;
        _middleware = middleware;
    }

    return self;
}

- (AMALogOutput *)outputByChangingLogLevel:(AMALogLevel)logLevel
{
    return [(AMALogOutput *)[self.class alloc] initWithChannel:self.channel
                                                         level:logLevel
                                                     formatter:self.formatter
                                                    middleware:self.middleware];
}

- (BOOL)isEqual:(AMALogOutput *)other
{
    if (self == other) {
        return YES;
    }
    if (other == nil || [[other class] isEqual:[self class]] == NO) {
        return NO;
    }
    if ([self.channel isEqual:other.channel] == NO) {
        return NO;
    }
    if (self.logLevel != other.logLevel) {
        return NO;
    }
    if (self.formatter != other.formatter && [self.formatter isEqual:other.formatter] == NO) {
        return NO;
    }
    if (self.middleware != other.middleware && [self.middleware isEqual:other.middleware] == NO) {
        return NO;
    }
    return YES;
}

- (NSUInteger)hash
{
    NSUInteger hash = [self.channel hash];
    hash = hash * 31u + (NSUInteger)self.logLevel;
    hash = hash * 31u + [self.formatter hash];
    hash = hash * 31u + [self.middleware hash];
    return hash;
}

- (BOOL)isAsyncLoggingAcceptable
{
    return self.middleware.isAsyncLoggingAcceptable;
}

- (BOOL)isMatchingChannel:(AMALogChannel)channel
{
    return [self.channel isEqual:channel];
}

- (BOOL)canLogToChannel:(AMALogChannel)channel withLevel:(AMALogLevel)level
{
    return [self isMatchingChannel:channel] && (self.logLevel & level) != 0;
}

- (void)logMessage:(AMALogMessage *)message
{
    NSString *stringMessage = [self.formatter messageToString:message];
    [self.middleware logMessage:stringMessage level:message.level];
}

@end


#import <AppMetricaLog/AppMetricaLog.h>

@protocol AMALogMiddleware;
@protocol AMALogMessageFormatting;
@class AMALogMessage;

@interface AMALogOutput : NSObject

@property (nonatomic, copy,   readonly) AMALogChannel channel;
@property (nonatomic, assign, readonly) AMALogLevel logLevel;
@property (nonatomic, strong, readonly) id<AMALogMessageFormatting> formatter;
@property (nonatomic, strong, readonly) id<AMALogMiddleware> middleware;

- (instancetype)initWithChannel:(AMALogChannel)channel
                          level:(AMALogLevel)level
                      formatter:(id<AMALogMessageFormatting>)formatter
                     middleware:(id<AMALogMiddleware>)middleware;

- (AMALogOutput *)outputByChangingLogLevel:(AMALogLevel)logLevel;

- (BOOL)isAsyncLoggingAcceptable;
- (BOOL)isMatchingChannel:(AMALogChannel)channel;

- (BOOL)canLogToChannel:(AMALogChannel)channel withLevel:(AMALogLevel)level;
- (void)logMessage:(AMALogMessage *)message;

@end

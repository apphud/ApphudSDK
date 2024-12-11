
#import <AppMetricaLog/AppMetricaLog.h>

@protocol AMALogMessageFormatting;
@protocol AMALogMiddleware;

@interface AMALogOutputFactory : NSObject

- (AMALogOutput *)outputWithChannel:(AMALogChannel)channel
                              level:(AMALogLevel)level
                          formatter:(id<AMALogMessageFormatting>)formatter
                         middleware:(id<AMALogMiddleware>)middleware;

@end

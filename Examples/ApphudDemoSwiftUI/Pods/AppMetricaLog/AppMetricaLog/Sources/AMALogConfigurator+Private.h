
#import <AppMetricaLog/AppMetricaLog.h>

@class AMALogFacade;
@class AMALogOutputFactory;
@class AMALogMessageFormatterFactory;

@interface AMALogConfigurator ()

- (instancetype)initWithLog:(AMALogFacade *)log
           logOutputFactory:(AMALogOutputFactory *)factory
           formatterFactory:(AMALogMessageFormatterFactory *)formatterFactory;

@end


#import <AppMetricaLog/AppMetricaLog.h>

NS_ASSUME_NONNULL_BEGIN

@class AMALogFacade;

NS_SWIFT_NAME(LogConfigurator)
@interface AMALogConfigurator : NSObject

- (instancetype)initWithLog:(AMALogFacade *)log;

- (void)setChannel:(AMALogChannel)channel enabled:(BOOL)enabled;
- (void)setupLogWithChannel:(AMALogChannel)channel;

@end

NS_ASSUME_NONNULL_END

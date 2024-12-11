
#import "AMAReporterStateStorage.h"

@interface AMAReporterStateStorage (Migration)

- (void)updateAppEnvironmentJSON:(NSString *)json;
- (void)updateLastStateSendDate:(NSDate *)date;

@end

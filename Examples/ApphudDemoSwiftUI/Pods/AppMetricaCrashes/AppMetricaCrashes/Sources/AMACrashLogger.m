
#import "AMACrashLogger.h"
#import "AMACrashLogging.h"

static NSString *const kAMACrashDetectingNotEnabled = @"%@ Crash reporting is not enabled.";

@implementation AMACrashLogger

+ (void)logCrashDetectingNotEnabled:(NSString *)reason
{
    AMALogError(kAMACrashDetectingNotEnabled, reason);
}

@end

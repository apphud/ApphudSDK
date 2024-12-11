
#import "AMACrashLogger.h"
#import <Foundation/Foundation.h>

@interface AMACrashLogger : NSObject

+ (void)logCrashDetectingNotEnabled:(NSString *)reason;

@end

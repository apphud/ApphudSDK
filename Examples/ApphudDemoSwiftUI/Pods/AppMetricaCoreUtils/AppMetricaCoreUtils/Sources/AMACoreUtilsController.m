
#import <Foundation/Foundation.h>
#import "AMACoreUtilsLogging.h"

@interface AMACoreUtilsController : NSObject
@end

@implementation AMACoreUtilsController

+ (void)load
{
    if (self == [AMACoreUtilsController class]) {
        [[[self class] logConfigurator] setupLogWithChannel:AMA_LOG_CHANNEL];
        [[[self class] logConfigurator] setChannel:AMA_LOG_CHANNEL enabled:NO];
    }
}

+ (AMALogConfigurator *)logConfigurator
{
    static AMALogConfigurator *logConfigurator = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @autoreleasepool {
            logConfigurator = [AMALogConfigurator new];
        }
    });
    return logConfigurator;
}

@end

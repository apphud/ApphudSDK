
#import "AMADecodedCrashSerializer+CustomEventParameters.h"
#import <AppMetricaCoreExtension/AppMetricaCoreExtension.h>
#import "AMACrashReportCrash.h"
#import "AMACrashReportError.h"
#import "AMADecodedCrash.h"
#import "AMAInfo.h"

@implementation AMADecodedCrashSerializer (CustomEventParameters)

- (AMAEventPollingParameters *)eventParametersFromDecodedData:(AMADecodedCrash *)decodedCrash
                                                forEventType:(AMACrashEventType)eventType
                                                       error:(NSError **)error
{
    NSData *rawData = [self dataForCrash:decodedCrash error:error];
    if (rawData == nil) {
        return nil;
    }
    
    AMAEventPollingParameters *encodedEvent = [[AMAEventPollingParameters alloc] initWithEventType:eventType];
    encodedEvent.fileName = [NSString stringWithFormat:@"%@.crash", [[NSUUID UUID] UUIDString]];
    encodedEvent.data = rawData;
    encodedEvent.creationDate = decodedCrash.info.timestamp;
    encodedEvent.appState = decodedCrash.appState;
    encodedEvent.eventEnvironment = decodedCrash.errorEnvironment;
    encodedEvent.appEnvironment = decodedCrash.appEnvironment;
    
    return encodedEvent;
}

- (AMAEventPollingParameters *)eventParametersFromDecodedData:(AMADecodedCrash *)decodedCrash error:(NSError **)error
{
    AMACrashEventType type = decodedCrash.crash.error.type == AMACrashTypeMainThreadDeadlock
        ? AMACrashEventTypeANR
        : AMACrashEventTypeCrash;
    
    return [self eventParametersFromDecodedData:decodedCrash forEventType:type error:error];
}

@end

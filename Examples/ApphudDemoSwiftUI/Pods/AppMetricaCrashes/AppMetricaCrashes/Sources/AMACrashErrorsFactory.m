
#import "AMACrashLogging.h"
#import "AMACrashErrorsFactory.h"

@implementation AMACrashErrorsFactory

+ (NSError *)crashReportDecodingError
{
    return [AMAErrorUtilities errorWithCode:AMAAppMetricaEventErrorCodeInvalidName
                                description:@"Crash report decoding failed"];
}

+ (NSError *)crashReportRecrashError
{
    return [AMAErrorUtilities internalErrorWithCode:AMAAppMetricaInternalEventErrorCodeRecrash
                                        description:@"Recrash report was found in crash report"];
}

+ (NSError *)crashUnsupportedReportVersionError:(id)version
{
    return [AMAErrorUtilities internalErrorWithCode:AMAAppMetricaInternalEventErrorCodeUnsupportedReportVersion
                                        description:[NSString stringWithFormat:@"Crash report version unsupported: <%@>", version]];
}

+ (NSError *)crashReporterNotReadyError
{
    return [AMAErrorUtilities internalErrorWithCode:AMAAppMetricaInternalEventErrorCodeInternalInconsistency
                                        description:@"Crash reporter is not configured"];
}

@end

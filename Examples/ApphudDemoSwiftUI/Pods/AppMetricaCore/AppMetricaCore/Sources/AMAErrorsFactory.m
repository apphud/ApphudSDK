
#import "AMACore.h"
#import "AMAErrorsFactory.h"

@implementation AMAErrorsFactory

#pragma mark - Metrica's errors

+ (NSError *)appMetricaNotStartedError
{
    return [AMAErrorUtilities errorWithCode:AMAAppMetricaEventErrorCodeInitializationError
                                description:@"activateWithApiKey: or activateWithConfiguration: aren't called"];
}

#pragma mark - Reporter's errors

+ (NSError *)sessionNotLoadedError
{
    return [AMAErrorUtilities errorWithCode:AMAAppMetricaEventErrorCodeInitializationError
                                description:@"Session is not loaded"];
}

+ (NSError *)internalInconsistencyError
{
    return [AMAErrorUtilities internalErrorWithCode:AMAAppMetricaInternalEventErrorCodeInternalInconsistency
                                        description:@"Database inconsistency error"];
}

#pragma mark - Session's errors

+ (NSError *)badEventNameError:(NSString *)name
{
    NSString *errorMsg = [NSString stringWithFormat:@"Event name '%@' is incorrect", name];
    return [AMAErrorUtilities errorWithCode:AMAAppMetricaEventErrorCodeInvalidName
                                description:errorMsg];
}

+ (NSError *)badErrorMessageError:(NSString *)name
{
    NSString *errorMsg = [NSString stringWithFormat:@"Error message '%@' is incorrect", name];
    return [AMAErrorUtilities errorWithCode:AMAAppMetricaEventErrorCodeInvalidName
                                description:errorMsg];
}

+ (NSError *)deepLinkUrlOfUnknownTypeError:(NSString *)url
{
    NSString *description = [NSString stringWithFormat:@"URL value '%@' of unknown type", url];

    return [AMAErrorUtilities errorWithCode:AMAAppMetricaEventErrorCodeInvalidName
                                description:description];
}

+ (NSError *)emptyDeepLinkUrlOfUnknownTypeError
{
    return [AMAErrorUtilities errorWithCode:AMAAppMetricaEventErrorCodeInvalidName
                                description:@"Empty URL value of unknown type"];
}

+ (NSError *)emptyDeepLinkUrlOfTypeError:(NSString *)type
{
    NSString *description = [NSString stringWithFormat:@"Empty '%@' URL value", type];

    return [AMAErrorUtilities errorWithCode:AMAAppMetricaEventErrorCodeInvalidName
                                description:description];
}

+ (NSError *)eventTypeReservedError:(NSUInteger)eventType
{
    NSString *errorMsg =
        [NSString stringWithFormat:@"Event type with number '%lu' is reserved", (unsigned long)eventType];
    return [AMAErrorUtilities errorWithCode:AMAAppMetricaEventErrorCodeInvalidName
                                description:errorMsg];
}

#pragma mark - Impl's errors

+ (NSError *)reporterNotReadyError
{
    return [AMAErrorUtilities errorWithCode:AMAAppMetricaEventErrorCodeInitializationError
                                description:@"Reporter is not ready yet"];
}

#pragma mark - UserProfile

+ (NSError *)emptyUserProfileError
{
    return [AMAErrorUtilities errorWithCode:AMAAppMetricaEventErrorCodeEmptyUserProfile
                                description:@"User profile is empty. Attributes may have been ignored. See log."];
}

#pragma mark - Revenue

+ (NSError *)invalidRevenueCurrencyError:(NSString *)currency
{
    NSString *description =
        [NSString stringWithFormat:@"Invalid currency code '%@'. Expected ISO 4217 format.", currency];
    return [AMAErrorUtilities errorWithCode:AMAAppMetricaEventErrorCodeInvalidRevenueInfo
                                description:description];
}

+ (NSError *)zeroRevenueQuantityError
{
    return [AMAErrorUtilities errorWithCode:AMAAppMetricaEventErrorCodeInvalidRevenueInfo
                                description:@"Quantity can't be zero."];
}

#pragma mark - AdRevenue

+ (NSError *)invalidAdRevenueCurrencyError:(NSString *)currency
{
    NSString *description =
        [NSString stringWithFormat:@"Invalid currency code '%@'. Expected ISO 4217 format.", currency];
    return [AMAErrorUtilities errorWithCode:AMAAppMetricaEventErrorCodeInvalidAdRevenueInfo
                                description:description];
}

#pragma mark - Server response

+ (NSError *)badServerResponseError
{
    return [NSError errorWithDomain:NSURLErrorDomain
                               code:NSURLErrorBadServerResponse
                           userInfo:nil];
}

@end

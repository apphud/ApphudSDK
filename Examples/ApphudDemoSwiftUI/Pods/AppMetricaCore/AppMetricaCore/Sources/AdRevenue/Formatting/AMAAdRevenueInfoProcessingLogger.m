
#import "AMACore.h"
#import "AMAAdRevenueInfoProcessingLogger.h"

#define Log(format, ...) AMALogWarn(format, ##__VA_ARGS__)

@implementation AMAAdRevenueInfoProcessingLogger

#pragma mark - Public -

- (void)logTruncationOfType:(NSString *)type value:(NSString *)value maxLength:(NSUInteger)maxLength
{
    Log(@"AdRevenue %@ '%@' was truncated. Max length is '%lu'.", type, value, (unsigned long)maxLength);
}

- (void)logTruncationOfPayloadString:(NSString *)payloadString maxLength:(NSUInteger)maxLength
{
    Log(@"AdRevenue payload was truncated. JSON-serialized string: '%@'. Max length is '%lu'.",
        payloadString, (unsigned long)maxLength);
}

- (void)logInvalidCurrency:(NSString *)currency
{
    NSString *reason = [NSString stringWithFormat:@"currency '%@' doesn't correspond ISO 4217", currency];
    [self logAdRevenueEventIsRejectedWithReason:reason];
}

#pragma mark - Private -

- (void)logAdRevenueEventIsRejectedWithReason:(NSString *)reason
{
    Log(@"AdRevenue event was rejected: %@.", reason);
}

@end

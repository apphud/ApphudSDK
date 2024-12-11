
#import "AMACore.h"
#import "AMARevenueInfoProcessingLogger.h"

#define Log(format, ...) AMALogWarn(format, ##__VA_ARGS__)

@implementation AMARevenueInfoProcessingLogger

- (void)logTruncationOfType:(NSString *)type value:(NSString *)value maxLength:(NSUInteger)maxLength
{
    Log(@"Revenue %@ '%@' was truncated. Max length is '%lu'.", type, value, (unsigned long)maxLength);
}

- (void)logTruncationOfReceiptDataWithLength:(NSUInteger)length maxSize:(NSUInteger)maxSize
{
    Log(@"Revenue receipt data was truncated. Data size is '%lu'. Max size is '%lu'.",
        (unsigned long)length, (unsigned long)maxSize);
}

- (void)logTruncationOfPayloadString:(NSString *)payloadString maxLength:(NSUInteger)maxLength
{
    Log(@"Revenue payload was truncated. JSON-serialized string: '%@'. Max length is '%lu'.",
        payloadString, (unsigned long)maxLength);
}

- (void)logRevenueEventIsRejectedWithReason:(NSString *)reason
{
    Log(@"Revenue event was rejected: %@.", reason);
}

- (void)logZeroQuantity
{
    [self logRevenueEventIsRejectedWithReason:@"quantity can't be zero"];
}

- (void)logInvalidCurrency:(NSString *)currency
{
    NSString *reason = [NSString stringWithFormat:@"currency '%@' doesn't correspond ISO 4217", currency];
    [self logRevenueEventIsRejectedWithReason:reason];
}

- (void)logInAppValidationProblemWithReason:(NSString *)reason
{
    Log(@"In-App Purchase won't be validated: %@. See AMARevenueInfo.h for more information.", reason);
}

- (void)logTransactionIDIsMissing
{
    [self logInAppValidationProblemWithReason:@"transaction ID is missing"];
}

- (void)logReceiptDataIsMissing
{
    [self logInAppValidationProblemWithReason:@"receipt data is missing"];
}

@end

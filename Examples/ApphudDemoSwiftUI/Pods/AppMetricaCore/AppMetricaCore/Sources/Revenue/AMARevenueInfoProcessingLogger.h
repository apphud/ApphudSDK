
#import <Foundation/Foundation.h>

@interface AMARevenueInfoProcessingLogger : NSObject

- (void)logTruncationOfType:(NSString *)type value:(NSString *)value maxLength:(NSUInteger)maxLength;
- (void)logTruncationOfReceiptDataWithLength:(NSUInteger)length maxSize:(NSUInteger)maxSize;
- (void)logTruncationOfPayloadString:(NSString *)payloadString maxLength:(NSUInteger)maxLength;

- (void)logZeroQuantity;
- (void)logInvalidCurrency:(NSString *)currency;

- (void)logTransactionIDIsMissing;
- (void)logReceiptDataIsMissing;

@end

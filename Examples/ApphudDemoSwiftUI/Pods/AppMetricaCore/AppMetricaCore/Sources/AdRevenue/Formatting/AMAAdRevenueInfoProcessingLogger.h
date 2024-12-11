
#import <Foundation/Foundation.h>

@interface AMAAdRevenueInfoProcessingLogger : NSObject

- (void)logTruncationOfType:(NSString *)type value:(NSString *)value maxLength:(NSUInteger)maxLength;
- (void)logTruncationOfPayloadString:(NSString *)payloadString maxLength:(NSUInteger)maxLength;

- (void)logInvalidCurrency:(NSString *)currency;

@end

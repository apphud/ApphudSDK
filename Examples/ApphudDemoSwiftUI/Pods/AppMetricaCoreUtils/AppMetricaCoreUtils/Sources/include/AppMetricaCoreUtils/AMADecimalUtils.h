
#import <Foundation/Foundation.h>

NS_SWIFT_NAME(DecimalUtils)
@interface AMADecimalUtils : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (NSDecimalNumber *)decimalNumber:(NSDecimalNumber *)number
             bySafelyMultiplyingBy:(NSDecimalNumber *)anotherNumber
                                or:(NSDecimalNumber *)defaultNumber;
+ (NSDecimalNumber *)decimalNumber:(NSDecimalNumber *)number
                bySafelyDividingBy:(NSDecimalNumber *)anotherNumber
                                or:(NSDecimalNumber *)defaultNumber;
+ (NSDecimalNumber *)decimalNumber:(NSDecimalNumber *)number
                    bySafelyAdding:(NSDecimalNumber *)anotherNumber
                                or:(NSDecimalNumber *)defaultNumber;
+ (NSDecimalNumber *)decimalNumber:(NSDecimalNumber *)number
               bySafelySubtracting:(NSDecimalNumber *)anotherNumber
                                or:(NSDecimalNumber *)defaultNumber;
+ (NSDecimalNumber *)decimalNumberWithString:(NSString *)string or:(NSDecimalNumber *)defaultNumber;
+ (BOOL)fillMicrosValue:(int64_t *)value withDecimal:(NSDecimalNumber *)decimal;
+ (BOOL)fillMantissa:(int64_t *)mantissa exponent:(int32_t *)exponent withDecimal:(NSDecimalNumber *)decimal;
+ (NSDecimalNumber *)decimalFromMantissa:(int64_t)mantissa exponent:(int32_t)exponent;

@end

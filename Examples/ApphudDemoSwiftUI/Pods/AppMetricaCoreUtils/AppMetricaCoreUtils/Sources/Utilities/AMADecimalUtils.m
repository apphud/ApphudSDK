
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMACoreUtilsLogging.h"

static short const kAMAMicrosPower = 6;

@implementation AMADecimalUtils

#pragma mark - Public -

+ (NSDecimalNumber *)decimalNumberWithString:(NSString *)string or:(NSDecimalNumber *)defaultNumber
{
    NSDecimalNumber *result = nil;
    @try {
        result = [NSDecimalNumber decimalNumberWithString:string];
    } @catch (NSException *exception) {
        AMALogError(@"Exception: %@", exception);
        result = nil;
    }
    if ([self isValid:result] == NO) {
        return defaultNumber;
    }
    return result;
}

+ (NSDecimalNumber *)decimalNumber:(NSDecimalNumber *)number
             bySafelyMultiplyingBy:(NSDecimalNumber *)anotherNumber
                                or:(NSDecimalNumber *)defaultNumber
{
    NSDecimalNumber *result = defaultNumber;
    if ([self isValid:number] && [self isValid:anotherNumber]) {
        result = [number decimalNumberByMultiplyingBy:anotherNumber withBehavior:self.decimalNumberHandler];
        if ([self isValid:result] == NO) {
            result = defaultNumber;
        }
    }
    return result;
}

+ (NSDecimalNumber *)decimalNumber:(NSDecimalNumber *)number
                bySafelyDividingBy:(NSDecimalNumber *)anotherNumber
                                or:(NSDecimalNumber *)defaultNumber
{
    NSDecimalNumber *result = defaultNumber;
    if ([self isValid:number] && [self isValid:anotherNumber]) {
        result = [number decimalNumberByDividingBy:anotherNumber withBehavior:self.decimalNumberHandler];
        if ([self isValid:result] == NO) {
            result = defaultNumber;
        }
    }
    return result;
}

+ (NSDecimalNumber *)decimalNumber:(NSDecimalNumber *)number
                    bySafelyAdding:(NSDecimalNumber *)anotherNumber
                                or:(NSDecimalNumber *)defaultNumber
{
    NSDecimalNumber *result = defaultNumber;
    if ([self isValid:number] && [self isValid:anotherNumber]) {
        @try {
            result = [number decimalNumberByAdding:anotherNumber];
        } @catch (NSException *exception) {
            AMALogError(@"Exception: %@", exception);
            result = defaultNumber;
        }
    }
    return result;
}

+ (NSDecimalNumber *)decimalNumber:(NSDecimalNumber *)number
               bySafelySubtracting:(NSDecimalNumber *)anotherNumber
                                or:(NSDecimalNumber *)defaultNumber
{
    NSDecimalNumber *result = defaultNumber;
    if ([self isValid:number] && [self isValid:anotherNumber]) {
        @try {
            result = [number decimalNumberBySubtracting:anotherNumber];
        } @catch (NSException *exception) {
            AMALogError(@"Exception: %@", exception);
            result = defaultNumber;
        }
    }
    return result;
}

+ (BOOL)fillMicrosValue:(int64_t *)value withDecimal:(NSDecimalNumber *)decimal
{
    NSDecimalNumber *microsNumber = [decimal decimalNumberByMultiplyingByPowerOf10:kAMAMicrosPower
                                                                      withBehavior:[[self class] decimalNumberHandler]];
    return [self fillInt64Value:value withDecimal:microsNumber];
}

+ (NSDecimalNumber *)decimalFromMantissa:(int64_t)mantissa exponent:(int32_t)exponent
{
    BOOL isNegative = mantissa < 0;
    int32_t resultExponent = exponent;
    unsigned long long resultMantissa;
    if (isNegative) {
        resultMantissa = ((unsigned long long) -(mantissa + 1)) + 1;
    } else {
        resultMantissa = (unsigned long long) mantissa;
    }
    while (resultExponent < -(SHRT_MAX + 1) || resultExponent > SHRT_MAX) {
        if (resultExponent < -(SHRT_MAX + 1)) {
            resultMantissa /= 10;
            resultExponent++;
        } else {
            resultMantissa *= 10;
            resultExponent--;
        }
    }
    return [NSDecimalNumber decimalNumberWithMantissa:resultMantissa
                                             exponent:(short)resultExponent
                                           isNegative:isNegative];
}

+ (BOOL)fillMantissa:(int64_t *)mantissa exponent:(int32_t *)exponent withDecimal:(NSDecimalNumber *)decimal
{
    NSDecimal rawDecimal = decimal.decimalValue;
    if (NSDecimalIsNotANumber(&rawDecimal)) {
        return NO;
    }

    NSDecimalNumber *minMantissa = [NSDecimalNumber decimalNumberWithMantissa:((unsigned long long)LONG_LONG_MAX) + 1
                                                                     exponent:0
                                                                   isNegative:YES];
    NSDecimalNumber *maxMantissa = [NSDecimalNumber decimalNumberWithMantissa:LONG_LONG_MAX
                                                                     exponent:0
                                                                   isNegative:NO];

    int32_t resultExponent = (int32_t)rawDecimal._exponent;
    NSDecimalNumber *normalizedValue =
        [decimal decimalNumberByMultiplyingByPowerOf10:-(short)resultExponent
                                          withBehavior:[[self class] decimalNumberHandler]];
    while ([normalizedValue compare:minMantissa] == NSOrderedAscending
           || [normalizedValue compare:maxMantissa] == NSOrderedDescending) {
        NSDecimalNumber *roundValue =
            [normalizedValue decimalNumberByMultiplyingByPowerOf10:-1
                                                      withBehavior:[[self class] decimalNumberHandler]];

        // This condition is just for cycle safety.
        // For example, if there was no `if (NSDecimalIsNotANumber...` above, whithout this
        // condition the cycle is infinite.
        if ([roundValue isEqual:normalizedValue]) {
            AMALogError(@"Invalid decimal: %@", decimal);
            return NO;
        }
        normalizedValue = roundValue;
        resultExponent += 1;
    }

    if ([self fillInt64Value:mantissa withDecimal:normalizedValue] == NO) {
        return NO;
    }
    if (exponent != NULL) {
        *exponent = resultExponent;
    }
    return YES;
}

#pragma mark - Private -

+ (BOOL)isValid:(NSDecimalNumber *)number
{
    return number != nil && [number isEqualToNumber:[NSDecimalNumber notANumber]] == NO;
}

+ (BOOL)fillInt64Value:(int64_t *)value withDecimal:(NSDecimalNumber *)decimal
{
    if (value == NULL) {
        return YES;
    }

    const char *decimalString = [[decimal stringValue] UTF8String];
    if (decimalString == NULL) {
        AMALogError(@"Failed to serialize decimal: %@", decimal);
        return NO;
    }

    *value = (int64_t)strtoll(decimalString, NULL, 10);
    return YES;
}

+ (id<NSDecimalNumberBehaviors>)decimalNumberHandler
{
    static NSDecimalNumberHandler *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[NSDecimalNumberHandler alloc] initWithRoundingMode:NSRoundBankers
                                                                  scale:INT16_MAX // NO_SCALE
                                                       raiseOnExactness:NO
                                                        raiseOnOverflow:NO
                                                       raiseOnUnderflow:NO
                                                    raiseOnDivideByZero:NO];
    });
    return instance;
}

@end

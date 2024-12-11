
#import "AMAMetricaParametersScanner.h"

@implementation AMAMetricaParametersScanner

#pragma mark - Public -

+ (BOOL)scanAPIKey:(uint32_t *)APIKey inString:(NSString *)APIKeyCandidate
{
    return [[self class] scanUIntLargerThanZero:APIKey inString:APIKeyCandidate];
}

+ (BOOL)scanAppBuildNumber:(uint32_t *)appBuildNumber inString:(NSString *)appBuildNumberCandidate
{
    return [[self class] scanUInt:appBuildNumber inString:appBuildNumberCandidate];
}

#pragma mark - Private -

+ (BOOL)scanUIntLargerThanZero:(uint32_t *)result inString:(NSString *)string
{
    NSScanner *scanner = [NSScanner scannerWithString:string];
    long long ullValue;

    BOOL containsInteger = [scanner scanLongLong:&ullValue];
    BOOL containsNothingButSingleInteger = scanner.atEnd;
    BOOL resultFitsIn32Bits = ullValue <= UINT32_MAX;
    BOOL largerThanZero = ullValue > 0;

    BOOL success =
        containsInteger &&
        containsNothingButSingleInteger &&
        resultFitsIn32Bits &&
        largerThanZero;

    if (success) {
        *result = (uint32_t)ullValue;
    }
    else {
        *result = 0;
    }

    return success;
}

+ (BOOL)scanUInt:(uint32_t *)result inString:(NSString *)string
{
    NSScanner *scanner = [NSScanner scannerWithString:string];
    unsigned long long ullValue = 0;

    BOOL containsInteger = [scanner scanUnsignedLongLong:&ullValue];
    BOOL containsNothingButSingleInteger = scanner.atEnd;
    BOOL resultFitsIn32Bits = ullValue <= UINT32_MAX;

    BOOL success =
    containsInteger &&
    containsNothingButSingleInteger &&
    resultFitsIn32Bits;

    if (success) {
        *result = (uint32_t)ullValue;
    }
    else {
        *result = 0;
    }

    return success;
}

@end

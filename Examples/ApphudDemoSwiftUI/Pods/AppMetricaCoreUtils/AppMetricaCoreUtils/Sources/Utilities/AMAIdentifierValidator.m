
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@implementation AMAIdentifierValidator

#pragma mark - Public

+ (BOOL)isValidUUIDKey:(NSString *)key
{
    return [[NSUUID alloc] initWithUUIDString:key] != nil;
}

+ (BOOL)isValidNumericKey:(NSString *)key
{
    NSInteger numericKey = 0;
    BOOL isScanSucceed = [[NSScanner scannerWithString:key] scanInteger:&numericKey];
    if (isScanSucceed && numericKey > 0) {
        NSString *reversedKey = [NSString stringWithFormat:@"%li", (long)numericKey];
        return [reversedKey isEqual:key];
    }

    return NO;
}

+ (BOOL)isValidVendorIdentifier:(NSString *)identifier
{
    return [self isValidUUIDKey:identifier] && [self isMultipleUniqueCharactersIdentifier:identifier];
}

#pragma mark - Private

+ (BOOL)isMultipleUniqueCharactersIdentifier:(NSString *)identifier
{
    __block BOOL isMoreThanOneUniqueCharacter = NO;

    NSMutableSet *uniqueCharacters = [NSMutableSet set];
    NSString *hexIdentifier = [identifier stringByReplacingOccurrencesOfString:@"-" withString:@""];
    [hexIdentifier enumerateSubstringsInRange:NSMakeRange(0, hexIdentifier.length)
                                      options:NSStringEnumerationByComposedCharacterSequences
                                   usingBlock:^(NSString *substring, __unused NSRange substringRange, __unused NSRange enclosingRange, BOOL *stop) {
                                       [uniqueCharacters addObject:substring];
                                       if (uniqueCharacters.count > 1) {
                                           *stop = YES;
                                           isMoreThanOneUniqueCharacter = YES;
                                       }
                                   }];

    return isMoreThanOneUniqueCharacter;
}

@end


#import "AMACore.h"
#import "AMAUserProfileLogger.h"

@implementation AMAUserProfileLogger

+ (void)logAttributeUpdateIsIgnored:(NSString *)name reason:(NSString *)reason
{
    AMALogWarn(@"Attribute update with name '%@' is ignored. %@", name, reason);
}

+ (void)logAttributeNameTooLong:(NSString *)name
{
    [self logAttributeUpdateIsIgnored:name reason:@"Name is too long."];
}

+ (void)logTooManyCustomAttributesWithAttributeName:(NSString *)name
{
    [self logAttributeUpdateIsIgnored:name reason:@"Too many custom attribute updates were given."];
}

+ (void)logForbiddenAttributeNamePrefixWithName:(NSString *)name forbiddenPrefix:(NSString *)forbiddenPrefix
{
    NSString *reason =
        [NSString stringWithFormat:@"Prefix '%@' is reserved for predefined attributes.", forbiddenPrefix];
    [self logAttributeUpdateIsIgnored:name reason:reason];
}

+ (void)logStringAttributeValueTruncation:(NSString *)value attributeName:(NSString *)name
{
    AMALogWarn(@"Value of attribute '%@' was truncated: '%@'.", name, value);
}

+ (void)logInvalidDateWithAttributeName:(NSString *)name
{
    [self logAttributeUpdateIsIgnored:name reason:@"Invalid date was passed."];
}

+ (void)logInvalidGenderTypeWithAttributeName:(NSString *)name
{
    [self logAttributeUpdateIsIgnored:name reason:@"Invalid gender type was passed."];
}

+ (void)logProfileIDTooLong:(NSString *)profileID
{
    AMALogWarn(@"Profile ID '%@' was truncated.", profileID);
}

@end

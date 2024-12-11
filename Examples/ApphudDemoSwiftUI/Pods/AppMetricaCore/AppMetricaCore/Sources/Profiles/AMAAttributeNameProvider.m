
#import "AMAAttributeNameProvider.h"

NSString *const kAMAAttributeNameProviderPredefinedAttributePrefix = @"appmetrica";

@implementation AMAAttributeNameProvider

+ (NSString *)predefinedAttributeName:(NSString *)name
{
    return [NSString stringWithFormat:@"%@_%@", kAMAAttributeNameProviderPredefinedAttributePrefix, name];
}

+ (NSString *)name
{
    return [self predefinedAttributeName:@"name"];
}

+ (NSString *)gender
{
    return [self predefinedAttributeName:@"gender"];
}

+ (NSString *)birthDate
{
    return [self predefinedAttributeName:@"birth_date"];
}

+ (NSString *)notificationsEnabled
{
    return [self predefinedAttributeName:@"notifications_enabled"];
}

+ (NSString *)customStringWithName:(NSString *)name
{
    return name;
}

+ (NSString *)customNumberWithName:(NSString *)name
{
    return name;
}

+ (NSString *)customCounterWithName:(NSString *)name
{
    return name;
}

+ (NSString *)customBoolWithName:(NSString *)name
{
    return name;
}


@end

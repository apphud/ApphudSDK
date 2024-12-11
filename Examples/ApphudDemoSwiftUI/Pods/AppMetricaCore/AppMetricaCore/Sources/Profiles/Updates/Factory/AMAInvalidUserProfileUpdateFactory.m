
#import "AMAInvalidUserProfileUpdateFactory.h"
#import "AMAUserProfileUpdate.h"
#import "AMAProhibitingAttributeUpdateValidator.h"
#import "AMAUserProfileLogger.h"

@implementation AMAInvalidUserProfileUpdateFactory

+ (AMAUserProfileUpdate *)invalidUpdateWithLogBlock:(AMAProhibitingAttributeUpdateLogBlock)block
{
    AMAProhibitingAttributeUpdateValidator *validator =
        [[AMAProhibitingAttributeUpdateValidator alloc] initWithLogBlock:block];
    return [[AMAUserProfileUpdate alloc] initWithAttributeUpdate:nil validators:@[ validator ]];
}

+ (AMAUserProfileUpdate *)invalidDateUpdateWithAttributeName:(NSString *)name
{
    return [self invalidUpdateWithLogBlock:^(AMAAttributeUpdate *update) {
        [AMAUserProfileLogger logInvalidDateWithAttributeName:name];
    }];
}

+ (AMAUserProfileUpdate *)invalidGenderTypeUpdateWithAttributeName:(NSString *)name
{
    return [self invalidUpdateWithLogBlock:^(AMAAttributeUpdate *update) {
        [AMAUserProfileLogger logInvalidGenderTypeWithAttributeName:name];
    }];
}

@end

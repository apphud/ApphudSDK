
#import "AMAGenderAttribute.h"
#import "AMAStringAttribute.h"
#import "AMAInvalidUserProfileUpdateFactory.h"

@interface AMAGenderAttribute ()

@property (nonatomic, strong, readonly) AMAStringAttribute *stringAttribute;

@end

@implementation AMAGenderAttribute

- (instancetype)initWithStringAttribute:(AMAStringAttribute *)stringAttribute
{
    self = [super init];
    if (self != nil) {
        _stringAttribute = stringAttribute;
    }
    return self;
}

- (NSString *)stringIdentifierForGenderType:(AMAGenderType)genderType
{
    switch (genderType) {
        case AMAGenderTypeMale:
            return @"M";
        case AMAGenderTypeFemale:
            return @"F";
        case AMAGenderTypeOther:
            return @"O";
        default:
            return nil;
    }
}

- (AMAUserProfileUpdate *)withValue:(AMAGenderType)value
{
    AMAUserProfileUpdate *userProfileUpdate = nil;
    NSString *stringValue = [self stringIdentifierForGenderType:value];
    if (stringValue != nil) {
        userProfileUpdate = [self.stringAttribute withValue:stringValue];
    }
    else {
        userProfileUpdate =
            [AMAInvalidUserProfileUpdateFactory invalidGenderTypeUpdateWithAttributeName:self.stringAttribute.name];
    }
    return userProfileUpdate;
}

- (AMAUserProfileUpdate *)withValueReset
{
    return [self.stringAttribute withValueReset];
}

@end

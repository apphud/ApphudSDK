
#import "AMACustomAttributeUserProfileUpdateProvider.h"
#import "AMAAttributeUpdate.h"
#import "AMAUserProfileUpdate.h"
#import "AMAAttributeUpdateNamePrefixValidator.h"
#import "AMAAttributeUpdateNameLengthValidator.h"
#import "AMAAttributeUpdateCountValidator.h"

@implementation AMACustomAttributeUserProfileUpdateProvider

- (AMAUserProfileUpdate *)updateWithAttributeName:(NSString *)name
                                             type:(AMAAttributeType)type
                                      valueUpdate:(id<AMAAttributeValueUpdate>)valueUpdate
{
    AMAAttributeUpdate *attributeUpdate = [[AMAAttributeUpdate alloc] initWithName:name
                                                                              type:type
                                                                            custom:YES
                                                                       valueUpdate:valueUpdate];
    NSArray *validators = @[
        [[AMAAttributeUpdateCountValidator alloc] init],
        [[AMAAttributeUpdateNameLengthValidator alloc] init],
        [[AMAAttributeUpdateNamePrefixValidator alloc] init],
    ];
    return [[AMAUserProfileUpdate alloc] initWithAttributeUpdate:attributeUpdate validators:validators];
}

@end


#import "AMAPredefinedAttributeUserProfileUpdateProvider.h"
#import "AMAUserProfileUpdate.h"
#import "AMAAttributeUpdate.h"

@implementation AMAPredefinedAttributeUserProfileUpdateProvider

- (AMAUserProfileUpdate *)updateWithAttributeName:(NSString *)name
                                             type:(AMAAttributeType)type
                                      valueUpdate:(id<AMAAttributeValueUpdate>)valueUpdate
{
    AMAAttributeUpdate *attributeUpdate = [[AMAAttributeUpdate alloc] initWithName:name
                                                                              type:type
                                                                            custom:NO
                                                                       valueUpdate:valueUpdate];
    NSArray *validators = @[
    ];
    return [[AMAUserProfileUpdate alloc] initWithAttributeUpdate:attributeUpdate validators:validators];
}

@end

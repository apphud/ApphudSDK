
#import <Foundation/Foundation.h>
#import "AMAAttributeType.h"

@class AMAAttributeUpdate;
@class AMAUserProfileUpdate;
@protocol AMAAttributeValueUpdate;

@protocol AMAUserProfileUpdateProviding <NSObject>

- (AMAUserProfileUpdate *)updateWithAttributeName:(NSString *)name
                                             type:(AMAAttributeType)type
                                      valueUpdate:(id<AMAAttributeValueUpdate>)valueUpdate;

@end

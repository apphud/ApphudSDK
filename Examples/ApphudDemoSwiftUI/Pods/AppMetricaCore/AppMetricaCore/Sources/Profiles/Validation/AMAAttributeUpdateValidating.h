
#import <Foundation/Foundation.h>

@class AMAUserProfileModel;
@class AMAAttributeUpdate;

@protocol AMAAttributeUpdateValidating <NSObject>

- (BOOL)validateUpdate:(AMAAttributeUpdate *)update model:(AMAUserProfileModel *)model;

@end


#import <Foundation/Foundation.h>

@class AMAUserProfileModel;

@interface AMAUserProfileModelSerializer : NSObject

- (NSData *)dataWithModel:(AMAUserProfileModel *)model;

@end

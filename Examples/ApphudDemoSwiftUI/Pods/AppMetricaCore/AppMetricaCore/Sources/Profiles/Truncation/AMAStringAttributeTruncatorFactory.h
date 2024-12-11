
#import <Foundation/Foundation.h>

@class AMAStringAttributeTruncationProvider;

@interface AMAStringAttributeTruncatorFactory : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (AMAStringAttributeTruncationProvider *)nameTruncationProvider;
+ (AMAStringAttributeTruncationProvider *)genderTruncationProvider;
+ (AMAStringAttributeTruncationProvider *)birthDateTruncationProvider;
+ (AMAStringAttributeTruncationProvider *)customStringTruncationProvider;

@end

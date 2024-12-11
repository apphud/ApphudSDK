
#import <Foundation/Foundation.h>

@protocol AMAStringTruncating;

@interface AMAStringAttributeTruncationProvider : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithUnderlyingTruncator:(id<AMAStringTruncating>)underlyingTruncator;

- (id<AMAStringTruncating>)truncatorWithAttributeName:(NSString *)attributeName;

@end

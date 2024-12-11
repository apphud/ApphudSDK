
#import <Foundation/Foundation.h>
#import "AMACore.h"

@class AMAUserProfileLogger;

@interface AMAStringAttributeTruncator : NSObject <AMAStringTruncating>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithAttributeName:(NSString *)name
                  underlyingTruncator:(id<AMAStringTruncating>)underlyingTruncator;

@end


#import <Foundation/Foundation.h>
#import "AMAReachabilityStatus.h"

extern NSString *const kAMAReachabilityStatusDidChange;

@interface AMAReachability : NSObject

@property (nonatomic, assign, readonly) AMAReachabilityStatus status;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

+ (instancetype)sharedInstance;

- (BOOL)isNetworkReachable;

- (void)start;
- (void)shutdown;

@end


#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, AMAReachabilityStatus) {
    AMAReachabilityStatusUnknown = 0,
    AMAReachabilityStatusNotReachable = 1,
    AMAReachabilityStatusReachableViaWWAN = 2,
    AMAReachabilityStatusReachableViaWiFi = 3,
};

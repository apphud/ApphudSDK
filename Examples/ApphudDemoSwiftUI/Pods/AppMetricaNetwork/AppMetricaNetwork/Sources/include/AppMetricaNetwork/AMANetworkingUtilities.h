
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(NetworkingUtilities)
@interface AMANetworkingUtilities : NSObject

+ (void)addUserAgentHeadersToDictionary:(NSMutableDictionary *)dictionary;
+ (void)addSendTimeHeadersToDictionary:(NSMutableDictionary *)dictionary date:(NSDate *)date;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END

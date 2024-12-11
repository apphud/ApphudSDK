
#import <Foundation/Foundation.h>

@interface AMADefaultStartupHostsProvider : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (NSArray *)startupHostsWithAdditionalHosts:(NSArray *)additionalStartupHosts;

@end

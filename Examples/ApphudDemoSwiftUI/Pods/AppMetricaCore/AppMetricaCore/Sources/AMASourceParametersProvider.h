
#import <Foundation/Foundation.h>

@interface AMASourceParametersProvider : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (NSDictionary *)sourceParameters:(NSString *)apiKey;

@end


#import <Foundation/Foundation.h>

NS_SWIFT_NAME(URLUtilities)
@interface AMAURLUtilities : NSObject

+ (NSURL *)URLWithBaseURLString:(NSString *)baseURLString
              httpGetParameters:(NSDictionary *)httpGetParameters;
+ (NSURL *)URLWithBaseURLString:(NSString *)baseURLString
                 pathComponents:(NSArray *)pathComponents
              httpGetParameters:(NSDictionary *)httpGetParameters;

+ (NSDictionary *)HTTPGetParametersForURL:(NSURL *)url;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

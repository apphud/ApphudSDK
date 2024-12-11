
#import <Foundation/Foundation.h>

@interface AMADeepLinkPayloadFactory : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (NSDictionary *)deepLinkPayloadForURL:(NSURL *)URL
                                 ofType:(NSString *)type
                                 isAuto:(BOOL)isAuto
                                  error:(NSError **)error;

@end


#import <Foundation/Foundation.h>

@interface AMALocationRequestParameters : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (NSDictionary *)parametersWithRequestIdentifier:(NSNumber *)requestIdentifier;

@end
